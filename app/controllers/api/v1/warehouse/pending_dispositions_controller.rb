class Api::V1::Warehouse::PendingDispositionsController < ApplicationController

  # GET api/v1/warehouse/pending_dispositions
  def index
    get_pending_dispositions
    if current_user.roles.last.name == "Default User"
      @items = check_user_accessibility(@pending_dispositions, @distribution_center_detail)
      @pending_dispositions = @pending_dispositions.where(id: @items.pluck(:id)).order('created_at desc')
    end
    @pending_dispositions = @pending_dispositions.page(@current_page).per(@per_page)
    render json: @pending_dispositions, meta: pagination_meta(@pending_dispositions)
  end

  def search_item
    set_pagination_params(params)
    get_distribution_centers
    search_param = params['search'].split(',').collect(&:strip).flatten
    ids = @distribution_center.present? ? [@distribution_center.id] : current_user.distribution_centers.pluck(:id)
    if params['search_in'] == 'brand'
      @pending_dispositions = PendingDisposition.joins(:inventory).where(is_active: true, distribution_center_id: ids).where("lower(pending_dispositions.details ->> 'brand') IN (?) ", search_param.map(&:downcase))
    else
      @pending_dispositions = PendingDisposition.joins(:inventory).where(is_active: true, distribution_center_id: ids).where("lower(pending_dispositions.#{params['search_in']}) IN (?) ", search_param.map(&:downcase))
    end
    # @pending_dispositions = @pending_dispositions.where("inventories.is_putaway_inwarded IS NOT false")
    @pending_dispositions = @pending_dispositions.where("lower(pending_dispositions.details ->> 'criticality') IN (?) ", params[:criticality]) if params['criticality'].present?
    @pending_dispositions = @pending_dispositions.page(@current_page).per(@per_page)
    render json: @pending_dispositions, meta: pagination_meta(@pending_dispositions)
  end

  def set_disposition
    disposition = LookupValue.find_by_id(params[:disposition])
    @pending_dispositions = PendingDisposition.includes(:inventory).where(id: params[:pending_disposition_ids])
    policy = LookupValue.find_by_id(params['policy']) if params['policy'].present?
    if @pending_dispositions.present? && disposition.present?
      @pending_dispositions.each do |pd|
        begin
          ActiveRecord::Base.transaction do
            inventory = pd.inventory
            pd.details['disposition_set'] = true
            pd.is_active = false
            pd.disposition_remark = params['desposition_remarks']
            inventory.disposition = disposition.original_code
            if disposition.original_code == 'Liquidation'
              pd.details['policy_id'] = policy.id
              pd.details['policy_type'] = policy.original_code
              inventory.details['policy_id'] = policy.id
              inventory.details['policy_type'] = policy.original_code
            end
            pd_status_closed = LookupValue.find_by_code(Rails.application.credentials.pending_disposition_status_pending_disposition_closed)
            inventory.disposition = disposition.original_code
            pd.status_id = pd_status_closed.id
            pd.status = pd_status_closed.original_code
            pd.is_active = false
            inventory.save
            if pd.save!
              pdh = pd.pending_disposition_histories.new(status_id: pd.status_id)
              pdh.details = {}
              key = "#{pd.status.try(:downcase).try(:strip).split(' ').join('_')}_created_at"
              pdh.details[key] = Time.now
              pdh.details["status_changed_by_user_id"] = current_user.id
              pdh.details["status_changed_by_user_name"] = current_user.full_name
              pdh.save!
            end
            DispositionRule.create_bucket_record(disposition.original_code, inventory, "Pending Disposition", current_user.id)
          end
        rescue ActiveRecord::RecordInvalid => exception
          render json: "Something Went Wrong", status: :unprocessable_entity
          return
        end
      end

      get_pending_dispositions
      @pending_dispositions = @pending_dispositions.page(@current_page).per(@per_page)
      render json: @pending_dispositions, meta: pagination_meta(@pending_dispositions)
    else
      render json: "Please provide Valid Ids", status: :unprocessable_entity
    end
  end

  def get_dispositions
    lookup_key = LookupKey.find_by_code('WAREHOUSE_DISPOSITION')
    dispositions = lookup_key.lookup_values.where.not(original_code: ['Pending Disposition', 'RTV', 'Capital Asset']).order('original_code asc')
    policy_key = LookupKey.find_by_code('POLICY')
    policies = policy_key.lookup_values
    render json: {dispositions: dispositions.as_json(only: [:id, :original_code]), policies: policies.as_json(only: [:id, :original_code])}
  end

  private

  def get_pending_dispositions
    set_pagination_params(params)
    get_distribution_centers
    @pending_dispositions = PendingDisposition.includes(:inventory).where(distribution_center_id: @distribution_center_ids, is_active: true).order('pending_dispositions.updated_at desc')
    # @pending_dispositions = @pending_dispositions.where("inventories.is_putaway_inwarded IS NOT false")
    @pending_dispositions = @pending_dispositions.where("lower(pending_dispositions.details ->> 'criticality') IN (?) ", params[:criticality]) if params['criticality'].present?
  end

  def check_user_accessibility(items, detail)
    result = []
    items.each do |item|
      origin_location_id = DistributionCenter.where(code: item.details["destination_code"]).pluck(:id)
      if ( (detail["grades"].include?("All") ? true : detail["grades"].include?(item.grade) ) && ( detail["brands"].include?("All") ? true : detail["brands"].include?(item.inventory.details["brand"]) ) && ( detail["warehouse"].include?(0) ? true : detail["warehouse"].include?(item.distribution_center_id) ) && ( detail["origin_fields"].include?(0) ? true : detail["origin_fields"].include?(origin_location_id)) )
        result << item 
      end
    end
    return result
  end

  def get_distribution_centers
    @distribution_center_ids = @distribution_center.present? ? [@distribution_center.id] : current_user.distribution_centers.pluck(:id)
    @distribution_center_detail = ""
    if ["Default User", "Site Admin"].include?(current_user.roles.last.name)
      id = []
      if @distribution_center.present?
        ids = [@distribution_center.id]
      else
        ids = current_user.distribution_centers.pluck(:id)
      end
      current_user.distribution_center_users.where(distribution_center_id: ids).each do |distribution_center_user|
        @distribution_center_detail = distribution_center_user.details.select{|d| d["disposition"] == "Pending Disposition" || d["disposition"] == "All"}.last
        if @distribution_center_detail.present?
          @distribution_center_ids = @distribution_center_detail["warehouse"].include?(0) ? DistributionCenter.all.pluck(:id) : @distribution_center_detail["warehouse"]
          return
        end
      end
    else
      @distribution_center_ids = @distribution_center.present? ? [@distribution_center.id] : DistributionCenter.all.pluck(:id)
    end
  end

end
