class Api::V2::Warehouse::CannibalizationsController < ApplicationController

  before_action -> { set_pagination_params(params) }, only: :index
  before_action :filter_cannibalization_items, :search_cannibalization_items, only: [:index]
  before_action :set_cannibalizations, only: [:change_disposition]

  def index
    @cannibalizations = @cannibalizations.order('updated_at desc').page(@current_page).per(@per_page)
    render_collection(@cannibalizations, Api::V2::Warehouse::CannibalizationSerializer)
  end

  def get_dispositions
    lookup_keys = LookupKey.where(code: ['WAREHOUSE_DISPOSITION', 'FORWARD_DISPOSITION'])
    dispositions = LookupValue.where(lookup_key_id: lookup_keys.pluck(:id), original_code: ['Brand Call-Log', 'Repair', 'Redeploy', 'Markdown', 'Liquidation', 'Production']).as_json(only: %i[id original_code])
    render json: { dispositions: dispositions }
  end

  def change_disposition
    ActiveRecord::Base.transaction do
      disposition = LookupValue.find_by(id: params[:disposition_id])
      raise CustomErrors, "Disposition can't be blank!" if disposition.blank?

      items_count = @cannibalizations.count
      @cannibalizations.each do |cannibalization|
        cannibalization.set_disposition(disposition.original_code, current_user)
      end

      render json: { message: "#{items_count} item(s) moved to #{disposition.original_code} disposition" }
    end
  end

  def get_bom
    @cannibalization = Cannibalization.find_by(id: params[:id])
    if @cannibalization.present?
      bom_child_cannibalizations = @cannibalization.sub_cannibalize_items.only_view_bom.order('updated_at desc')
      summary_child_cannibalizations = Cannibalization.unscoped.where("(cannibalizations.is_active IS TRUE OR cannibalizations.condition = 'Write Off')").where(parent_id: @cannibalization.id).only_work_in_progress_and_cannibalized.order('updated_at desc')
      bom_child_cannibalizations = ActiveModel::SerializableResource.new(bom_child_cannibalizations,each_serializer: Api::V2::Warehouse::CannibalizationSerializer)
      summary_child_cannibalizations = ActiveModel::SerializableResource.new(summary_child_cannibalizations,each_serializer: Api::V2::Warehouse::CannibalizationSerializer)
      render json: { bom_mapping_items: bom_child_cannibalizations, summary_items: summary_child_cannibalizations }
    else
      render_error("Could not find cannibalization with ID :: #{params[:id]}", 422)
    end
  end

  private

  def search_cannibalization_items
    @cannibalizations = @cannibalizations.search_by_text(params[:search_text]) if params[:search_text].present?
  end

  def filter_cannibalization_items
    @cannibalizations = Cannibalization
    @cannibalizations = @cannibalizations.filter(params[:filter]) if params[:filter].present?
    @cannibalizations = @cannibalizations.where(is_active: true, status: self.class::STATUS)
  end

  def set_cannibalization
    @cannibalization = Cannibalization.find_by(id: params[:id])

    render_error("Cannibalization is not present in the system.", 422) and return unless @cannibalization.present?
  end

  def set_cannibalizations
    @cannibalizations = Cannibalization.where(id: params[:cannibalization][:ids])
  end
end
