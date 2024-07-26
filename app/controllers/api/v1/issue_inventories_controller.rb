# frozen_string_literal: true

module Api
  module V1
    # Issues Inventory which are scanned, excess and shorts
    class IssueInventoriesController < ApplicationController
      before_action :filter_issue_inventories, only: %i[index update_status pending_approvals reject correct_excess approve get_filter_locations]
      before_action :filter_by_params, only: :index
      before_action :set_params, only: %i[index pending_approvals]
      def index
        common_response('Issue Inventories found', 200, 'issue_inventories',
                        @issue_inventories.page(@current_page).per(@per_page).as_json(methods: [:show_correct_access]), true)
      end

      def update_status
        status = params[:status].to_s.parameterize.underscore.to_sym
        return respond_with_error("Not allow to do '#{status.to_s.titleize}'") if @issue_inventories.pluck(:inventory_status).uniq.include?('short') && status != :write_off
        vendor_master = VendorMaster.find_by(vendor_code: params[:vendor_code])
        # TODO, as New Design for write off with/without debit not is not done, need to remove and allow
        # respond_with_error('Vendor is not found by code') and return if vendor_master.blank?

        details = { vendor_code: params[:vendor_code], claim_amount: params[:claim_amount], name: vendor_master&.vendor_name }
        update_inventory_status(:pending_for_approval, status, details)
        respond_with_success('Items has been sent to Business Head for approval.')
      end

      def correct_excess
        details = { sub_location_id: params[:sub_location_id] } if params[:sub_location_id].present?
        update_inventory_status(:pending_for_approval, :currect_excess, details.to_h)
        respond_with_success('Items has been sent to Business Head for approval.')
      end

      def pending_approvals
        search = params[:search]
        statuses = params[:inventory_statuses]
        qry = ['issue_inventories.tag_number in (?) OR issue_inventories.request_id in (?)', search, search] if search.present?
        filter = { inventory_status: statuses } if statuses.present?
        common_response('Issue Inventories Pending for Approval', 200, 'issue_inventories',
                        @issue_inventories.pending_for_approval.where(qry).where(filter).page(@current_page).per(@per_page), true)
      end

      def reject
        update_inventory_status('pending_for_action')
        respond_with_success('All selected inventories are moved to Issue items buckets.')
      end

      def approve
        update_inventory_status(:approved)
        respond_with_success('All selected inventories are approved.')
      end

      def get_filter_locations
        locations = @issue_inventories.pluck(:location).uniq
        render json: locations
      end

      private

      def filter_issue_inventories
        search_with = { physical_inspections: { status: 2 } }
        search_with.merge!({ id: params[:ids] }) if params[:ids].present? && ['get_filter_locations'].exclude?(action_name)
        @issue_inventories = IssueInventory.includes(:inventory).joins(:physical_inspection).where(search_with).order(updated_at: :desc)
        respond_with_error('No Issue inventories are found by provided ids') unless @issue_inventories.present?
      end

      def filter_by_params
        search = params[:search]
        locations = params[:locations]
        inventory_statuses = params[:inventory_statuses]
        statuses = params[:statuses]
        filter = {}
        qry = ['issue_inventories.tag_number in (?) OR issue_inventories.request_id in (?)', search, search] if search.present?

        filter.merge!({ location: locations }) if locations.present?
        filter.merge!({ inventory_status: inventory_statuses }) if inventory_statuses.present?
        filter.merge!({ status: statuses }) if statuses.present?
        @issue_inventories = @issue_inventories.where(qry).where(filter)
      end

      def update_inventory_status(status, current_status = nil, details = {})
        @issue_inventories.find_each do |issue_inventory|
          issue_inventory.current_user = current_user
          current_status = issue_inventory.current_status if current_status.nil?
          details = issue_inventory.details.to_h.merge(details)
          issue_inventory.update(status: status, current_status: current_status, details: details)
        end
      end

      def set_params
        set_pagination_params(params)
      end
    end
  end
end
