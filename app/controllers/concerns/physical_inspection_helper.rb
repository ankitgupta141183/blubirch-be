# frozen_string_literal: true

# its helper for physical inspection controller
module PhysicalInspectionHelper
  extend ActiveSupport::Concern

  private

  def find_physical_inspection
    @physical_inspection = PhysicalInspection.find_by(id: params[:id])
    respond_with_error('Request id is not available') if @physical_inspection.blank?
  end

  def physical_inspections
    @physical_inspections = if params[:from_mobile].present?
                              PhysicalInspection.open_requests
                            else
                              PhysicalInspection.all
                            end
  end

  def filter_by_params
    search = params[:search]
    statuses = params[:statuses]
    qry = {}
    qry.merge!({ request_id: search }) if search.present?
    qry.merge!({ status: statuses }) if statuses.present?
    @physical_inspections = @physical_inspections.order(updated_at: :desc).where(qry)
  end

  def obj_error
    respond_with_error(@physical_inspection.errors.full_messages.join(','))
  end

  def physical_inspection_params
    params.require(:physical_inspection).permit(:distribution_center_id, :inventory_type,
                                                brands: [], category_ids: [], article_ids: [],
                                                dispositions: [], assignee_ids: [], sub_location_ids: [], assignees_hash: {})
  end
end
