class Api::V2::Warehouse::LiquidationsController < ApplicationController
  STATUS = 'Pending Liquidation'

  before_action -> { set_pagination_params(params) }, only: :index
  before_action :get_distribution_centers, :filter_liquidation_items, :search_liquidation_items, :filter_based_on_categories, only: :index
  before_action :validate_inventory_grade_mapping, only: :create_lot, if: -> { current_user&.bidding_method == "hybrid" }

  def index
    if params['status'] == 'Pending B2C Publish'
      @liquidations = @liquidations.order('liquidations.updated_at desc').where(b2c_publish_status: [:publish_initiated, nil]).page(@current_page).per(@per_page)
    else
      @liquidations = @liquidations.order('liquidations.updated_at desc').page(@current_page).per(@per_page)
    end
    render_collection(@liquidations, Api::V2::Warehouse::LiquidationSerializer)
  end

  def category_list
    category_list = ClientCategory.active.order("name asc")
    render_collection_without_pagination(category_list, Api::V2::Warehouse::ClientCategorySerializer)
  end

  def formatted_category_list
    begin
      category_list =  ClientCategory.cache_json_tree_into_redis
      render json: { category_list: category_list }
    rescue Exception => message
      render_error(message.to_s, 500)
    end
  end

  def buyers
    buyers = BuyerMaster.all
    buyers = buyers.search_by_text(params[:search_text]) if params[:search_text].present?
    render json: { buyer_masters: buyers.as_json(only: :username, methods: :full_name) }
  end

  def inventories_images
    liquidations = Liquidation.includes(:inventory).where(id: params[:liquidation_ids])
    images = []
    liquidations.each do |liquidation|
      liquidation.inventory.inventory_grading_details.each do |detail|
        images << get_images_for_condition(detail, "Physical Condition")
        images << get_images_for_condition(detail, "Item Condition")
      end
    end
    images = images.flatten
    render json: { images: images }
  end

  private

  def get_images_for_condition detail, condition
    images = []
    grading_condition = detail.details.dig('final_grading_result', condition)
    if grading_condition.present?
      (grading_condition rescue []).each do |t|
        images << t["annotations"].map{|x| x["src"]} rescue []
      end
    end
    images
  end

  def search_liquidation_items
    @liquidations = @liquidations.search_by_text(params[:search_text]) if params[:search_text].present?
  end

  def filter_liquidation_items
    @liquidations = Liquidation
    @liquidations = @liquidations.filter(params[:filter]) if params[:filter].present?
    @liquidations = @liquidations.eager_load(inventory: [:client_category, :gate_pass]).includes(:liquidation_order, :distribution_center, :liquidation_request).where(distribution_center_id: @distribution_center_ids, is_active: true, status: self.class::STATUS)
  end

  def set_liquidations
    @liquidations = Liquidation.where(id: params[:liquidation][:ids])
  end

  def update_liquidations_status(status:, status_id:, message: "Successfully alloted!")
    @liquidations.update_all(status_id: status_id, status: status, updated_at: Time.current)
    create_liquidation_histories
    render_success_message(message, :ok)
  end

  def create_liquidation_histories
    liquidation_history_arr = []
    @liquidations.each do |liquidation|
      liquidation_history_arr << liquidation.create_liquidation_history(current_user)
    end
    LiquidationHistory.import(liquidation_history_arr) if liquidation_history_arr.present?
  end

  def filter_based_on_categories
    if params[:category_filter_count].present?
      if params[:category_filter_count].to_i == 1
        @liquidations = @liquidations.where("liquidations.details ->> 'category_l1' IN (?) ", params[:category_l1].to_s.strip.split(',')) if params[:category_l1].present?
      elsif params[:category_filter_count].to_i == 2
        query_condition = params[:category_l1].strip.split(',').count > 1 ? 'OR' : 'AND'
        @liquidations = @liquidations.where("(liquidations.details ->> 'category_l1' IN (?)) #{query_condition} (liquidations.details ->> 'category_l2' IN (?))", params[:category_l1].to_s.strip.split(','), params[:category_l2].to_s.strip.split(',')) if params[:category_l1].present? && params[:category_l2].present?
      elsif params[:category_filter_count].to_i == 3
        query_condition = params[:category_l1].strip.split(',').count > 1 || params[:category_l2].strip.split(',').count > 1 ? 'OR' : 'AND'
        @liquidations = @liquidations.where("(liquidations.details ->> 'category_l1' IN (?)) #{query_condition} (liquidations.details ->> 'category_l2' IN (?)) #{query_condition} (liquidations.details ->> 'category_l3' IN (?))", params[:category_l1].to_s.strip.split(','), params[:category_l2].to_s.strip.split(','), params[:category_l3].to_s.strip.split(',')) if params[:category_l1].present? && params[:category_l2].present? && params[:category_l3].present?
      elsif params[:category_filter_count].to_i == 4
        query_condition = params[:category_l1].strip.split(',').count > 1 && params[:category_l2].strip.split(',').count > 1 && params[:category_l3].strip.split(',').count > 1 ? 'OR' : 'AND'
        @liquidations = @liquidations.where("(liquidations.details ->> 'category_l1' IN (?)) #{query_condition} (liquidations.details ->> 'category_l2' IN (?)) #{query_condition} (liquidations.details ->> 'category_l3' IN (?)) #{query_condition} (liquidations.details ->> 'category_l4' IN (?))", params[:category_l1].to_s.strip.split(','), params[:category_l2].to_s.strip.split(','), params[:category_l3].to_s.strip.split(','), params[:category_l4].to_s.strip.split(',')) if params[:category_l1].present? && params[:category_l2].present? && params[:category_l3].present? && params[:category_l4].present?
      end
    end
  end

  #^ LOT before create validations
  def validate_liquidations_in_lot
    error_messages = []

    #& If name is blank
    error_messages << "Missing required param 'lot_name'." if lot_params[:lot][:lot_name].blank?

    #& If liquidation_ids is blank
    liquidations = Liquidation.where(id: lot_params[:liquidation_ids])
    error_messages << "No liquidations found!"  if liquidations.blank?

    #& ewaste_status based validation
    ewaste_statuses = liquidations.pluck(:is_ewaste)
    if ewaste_statuses.include?("yes") && (ewaste_statuses.include?("no") || ewaste_statuses.include?("not_defined"))
      error_messages << "e-waste item and an item marked as non e-waste can’t be part of the same lot'." 
    end

    tag_numbers = liquidations.where.not(liquidation_order_id: nil).pluck(:tag_number)
    if tag_numbers.present?
      error_messages << "liquidations items #{tag_numbers.join(', ')} are already part of another lot."
    end

    #& if liquidation has invalid status
    liquidations_with_invalid_status = liquidations.where.not(status: self.class::STATUS)
    error_messages << "Contains Liquidations which are not in '#{self.class::STATUS}'. " and return if liquidations_with_invalid_status.present?
  
    #& Delivery timeline validation
    delivery_timeline = params["delivery_timeline"]
    error_messages << "Delivery timeline should be present" if delivery_timeline.blank?
    error_messages << "Delivery timeline cannot be negative" if delivery_timeline.present? && delivery_timeline.to_i.negative?


    #& date time validation
    start_date = params["start_date"] 
    end_date = params["end_date"]
    error_messages << "delivery timeline should be present" if (start_date.present? && end_date.present?) && (start_date > end_date)

    #& Special character validation
    return render_error(error_messages.join(','), 422) if error_messages.present?
  end

  def validate_ewaste_status_for_moq
    "e-waste item can’t be part of the MOQ Lot'." if @liquidations.pluck(:is_ewaste).include?('yes')
  end

  def validate_inventory_grade_mapping
    where_qry = params[:sub_lot_quantity].to_a.map do |raw_data|
      "(liquidations.sku_code = '#{raw_data[:article_id]}' AND liquidations.grade = '#{raw_data[:grade]}')"
    end
    where_qry = where_qry.present? ? "(#{where_qry.join(" OR ")})" + " AND liquidations.status = 'MOQ Price'" : {"liquidations.id": params[:liquidation_ids]}
    article_ids = Inventory.validate_grade_mappings(where_qry)
    render_error("Grade mapping not avaibale for selected #{article_ids.join(', ')} items.", 422) if article_ids.any?
  end
end
