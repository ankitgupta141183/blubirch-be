# frozen_string_literal: true

module Api
  module V1
    # Physical inspections is used for checking the conditions of invetory physically.
    class PhysicalInspectionsController < ApplicationController
      include PhysicalInspectionHelper
      before_action :physical_inspections, :filter_by_params, only: :index
      before_action :find_physical_inspection, only: %i[scan_inventories update_status update_assignees]
      before_action :set_params, only: %i[index brands articles categories assignees issue_items]
      before_action :set_distribution_center, only: %i[get_sub_locations]

      def index
        # common_response('Physical Inspections found', 200, 'physical_inspections',
        #                 @physical_inspections.page(@current_page).per(@per_page), true)
        @physical_inspections = @physical_inspections.page(@current_page).per(@per_page)
        render json: @physical_inspections, meta: pagination_meta(@physical_inspections)
      end

      def create
        physical_inspection = PhysicalInspection.new(physical_inspection_params)
        if physical_inspection.save
          common_response("Request Successfully Created with id '#{physical_inspection.request_id}'", 200)
        else
          common_response(physical_inspection.errors.full_messages.join(','), 422)
        end
      end

      def update_status
        if @physical_inspection.update(status: params[:status])
          respond_with_success('Status updated.')
        else
          obj_error
        end
      end

      def update_assignees
        if @physical_inspection.update(assignees_hash: params[:assignees_hash])
          respond_with_success('Assignees are updated.')
        else
          obj_error
        end
      end

      def scan_inventories
        return common_response('Can\'t process request due to status is completed.', 422) if @physical_inspection.completed?
        hash = { physical_inspection_id: @physical_inspection.id,
                 distribution_center_id: @physical_inspection.distribution_center_id,
                 request_id: @physical_inspection.request_id }
        if ScanInventory.create_bulk_records(params[:tag_ids], hash)
          @physical_inspection.update(status: "in_progress")
          common_response('All Scan items are received', 200)
        else
          common_response('Some issues are occured while proecessing requests', 422)
        end
      end

      def brands
        brands = ClientSkuMaster.filter({ brand: params[:search] }).where.not(brand: nil).select('DISTINCT brand').page(@current_page).per(@per_page)
        common_response('Brand Lists', 200, :brands, brands, true)
      end

      def articles
        articles = ClientSkuMaster.filter({ code: params[:search] }).where.not(code: nil).select('DISTINCT code').page(@current_page).per(@per_page)
        common_response('Article Lists', 200, :articles, articles, true)
      end

      def categories
        categories = ClientCategory.filter({ name: params[:search] }).where(client_id: Client.first.id).select(:id, :name).page(@current_page).per(@per_page)
        common_response('Article Lists', 200, :client_categories, categories, true)
      end

      def dispositions
        lookup_key = LookupKey.find_by(code: 'WAREHOUSE_DISPOSITION')
        dispositions = lookup_key.lookup_values.pluck(:original_code)
        common_response('Disposition List', 200, :dispositions, dispositions)
      end

      def assignees
        users = User.where(status: 'Active')
        users = users.search_by_text(params[:search]) if params[:search].present?
        users = users.page(@current_page).per(@per_page)
        render json: users, each_serializer: UserAssigneesSerializer, meta: pagination_meta(users)
      end

      def issue_items
        physical_inspection = PhysicalInspection.find_by(id: params[:id])
        common_response('Physical inspectio not found', 422, :issue_items, []) and return if physical_inspection.blank?

        issue_items = physical_inspection.issue_inventories
        data = issue_items.page(@current_page).per(@per_page)
        render json: { shor_excess_count: issue_items.group(:inventory_status).count, issue_items: data, meta: pagination_meta(data) }
      end

      def get_sub_locations
        sub_locations = @distribution_center.sub_locations.as_json(only: [:id, :code])
        render json: { sub_locations: sub_locations }, status: 200
      end

      private

      def set_params
        set_pagination_params(params)
      end

      def set_distribution_center
        @distribution_center = current_user.distribution_centers.find_by(id: params[:distribution_center_id]) if params[:distribution_center_id].present?
        render_error('Distribution center not found.', 422) if @distribution_center.blank?
      end
    end
  end
end
