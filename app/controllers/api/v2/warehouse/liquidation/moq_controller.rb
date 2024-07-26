class Api::V2::Warehouse::Liquidation::MoqController < Api::V2::Warehouse::LiquidationsController
  STATUS = 'MOQ Price'
  before_action :validate_moq_lot_params, only: :create_lot
  before_action :set_liquidations, only: :move_to_competative_bidding
  before_action :get_distribution_centers, :filter_liquidation_items, :search_liquidation_items, :filter_based_on_categories, only: [:index, :article_id_list, :article_description_list, :liquidation_quantity_based_on_grade, :mrp_per_lot]

  # TODO implimentation for Create Lots will go here
  def create_lot
    begin
      ActiveRecord::Base.transaction do
        @parent_lot = LiquidationOrder.create_lot(@moq_lot_params, current_user)
        item_data = @moq_lot_params[:sub_lot_quantity].first
        liquidation = Liquidation.find_by(sku_code: item_data[:article_id], grade: item_data[:grade], status: 'MOQ Price')
        @parent_lot.details['moq_lot_params'] = @moq_lot_params
        @parent_lot.update(distribution_center_id: liquidation.distribution_center_id)
        CreateMoqSubLotWorker.perform_async(@parent_lot.id, @moq_lot_params.to_json, current_user.id)
      end
      render_success_message("Lot creation successful with the ID \"#{@parent_lot.id}\" & updated in the ‘Pending B2B Publish’ page", :ok)
    rescue => e
      render_error(e.message, 500)
    end
  end

  def move_to_competative_bidding
    status = LookupValue.find_by(code: Rails.application.credentials.liquidation_status_competitive_bidding_price)
    update_liquidations_status(status: status.original_code, status_id: status.id)
  end

  def article_id_list
    article_ids = @liquidations.pluck(:sku_code).uniq.compact.sort
    render json: { article_ids: article_ids }, status: 200
  end

  def article_description_list
    article_descriptions = @liquidations.pluck(:item_description).uniq.compact.sort
    render json: { article_descriptions: article_descriptions }, status: 200
  end

  def liquidation_quantity_based_on_grade
    return render_error("Missing 'search_value' in params.", 500) unless params[:search_value].present?
    liquidation = @liquidations.find_by("liquidations.sku_code = :search_value OR liquidations.item_description = :search_value", search_value: params[:search_value])
    return render_error("Data not found with given search value '#{params[:search_value]}'", 500) unless liquidation
    grade_with_quantity = @liquidations.where(sku_code: liquidation.sku_code).select(:grade).group(:grade).size.map{|k,v| {grade: k, quantity: v}} rescue {}
    render json: { article_id: liquidation&.sku_code, article_description: liquidation&.item_description, grade_with_quantity: grade_with_quantity }, status: 200
  end

  def mrp_per_lot
    return render_error("Missing 'sub_lot_quantity' in params.", 500) unless params[:sub_lot_quantity].present?
    mrp_per_lot = 0
    params[:sub_lot_quantity].each do |raw_data|
      mrp_per_lot += @liquidations.where(sku_code: raw_data[:article_id], grade: raw_data[:grade]).limit(raw_data[:lot_quantity].to_i).map(&:bench_mark_price).inject(:+)
    end
    render json: { mrp_per_lot: mrp_per_lot }, status: 200
  end

  private

  def validate_moq_lot_params
    permit_params = [ :lot_name, :lot_desc, :start_date, :end_date, :delivery_timeline, :maximum_lots_per_buyer, :possible_sub_lots, {sub_lot_quantity: [:article_id, :article_description, :grade, :lot_quantity]}, {lot_range: [:from_lot, :to_lot, :price_per_lot]} ]
    error_message = nil

    permit_params.each do |param|
      if param.is_a?(Hash)
        param.each do |key, value|
          value.each do |val|
            moq_lot_params[key].each do |v|
              error_message = " '#{val} = #{v[val]}'" and break if v[val].blank?
            end
          end
        end
      else
        error_message = " '#{param}'" and break if moq_lot_params.dig(:lot, param).blank? && moq_lot_params[param].blank?
      end
    end

    render_error('Invalid param' + error_message, 422) unless error_message.nil?
  end

  def moq_lot_params
    lot_type = LookupValue.find_by(code: Rails.application.credentials.liquidation_lot_type_moq_lot)
    lot_status = LookupValue.find_by(code: 'lot_status_creating_sub_lots')
    sub_lot_type = LookupValue.find_by(code: Rails.application.credentials.liquidation_lot_type_moq_sub_lot)
    sub_lot_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_ready_for_publishing_sub_lot)
    details = {'approved_buyer_ids' => params[:approved_buyer_ids], 'sub_lot_quantity' => params[:sub_lot_quantity], 'possible_sub_lots' => params[:possible_sub_lots]}
    @moq_lot_params = {
      lot: {
        lot_name: params[:lot_name],
        lot_desc: params[:lot_desc],
        end_date: params[:end_date],
        start_date: params[:start_date],
        status:lot_status.original_code,
        status_id: lot_status.id,
        lot_type: lot_type.original_code,
        lot_type_id: lot_type.id,
        delivery_timeline: params[:delivery_timeline],
        maximum_lots_per_buyer: params[:maximum_lots_per_buyer],
        details: details,
        created_by_id: current_user.id
      },
      possible_sub_lots: params[:possible_sub_lots],
      sub_lot_quantity: params[:sub_lot_quantity],
      lot_range: params[:lot_range],
      sub_lot_status: sub_lot_status.original_code,
      sub_lot_status_id: sub_lot_status.id,
      sub_lot_type: sub_lot_type.original_code,
      sub_lot_type_id: sub_lot_type.id
    }
  end
end
