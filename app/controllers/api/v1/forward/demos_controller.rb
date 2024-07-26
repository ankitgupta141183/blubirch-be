# frozen_string_literal: true

module Api
  module V1
    module Forward
      class DemosController < ApplicationController
        before_action :get_demos, only: %i[set_disposition transfer]

        def index
          set_pagination_params(params)
          filter_demos

          @demos = @demos.page(@current_page).per(@per_page)
          render_collection(@demos, Api::V1::Forward::DemoSerializer)
        end

        def get_dispositions
          lookup_key = LookupKey.find_by(code: 'FORWARD_DISPOSITION')
          dispositions = lookup_key.lookup_values.where(original_code: ['Saleable', 'Production', 'Usage', 'Replacement', 'Capital Assets']).as_json(only: %i[id original_code])
          render json: { dispositions: dispositions }
        end

        def get_locations
          locations = DistributionCenter.where('site_category in (?)', %w[D R B E]).as_json(only: %i[id code])
          render json: { locations: locations }
        end

        def set_disposition
          ActiveRecord::Base.transaction do
            disposition = LookupValue.find_by(id: params[:disposition_id])
            raise CustomErrors, "Disposition can't be blank" if disposition.blank?
            raise CustomErrors, 'Selected disposition is under development!' unless ['Saleable', 'Replacement', 'Capital Assets'].include? disposition.original_code

            items_count = @demos.count
            @demos.each do |demo|
              demo.set_disposition(disposition.original_code, current_user)
            end

            render json: { message: "#{items_count} item(s) moved to #{disposition.original_code} disposition" }
          end
        end

        def transfer
          ActiveRecord::Base.transaction do
            transfer_location = DistributionCenter.find_by(id: params[:location_id])
            location_ids = @demos.pluck(:distribution_center_id)
            raise CustomErrors, 'Invalid Location' if transfer_location.blank?
            raise CustomErrors, 'Items with different locations can not be transferred at once' if location_ids.uniq.count > 1
            raise CustomErrors, 'Items can not be transferred to the same location' if location_ids.first == transfer_location.id

            items_count = @demos.count
            @demos.each do |demo|
              demo.is_active = false
              demo.save!
              # TODO: Move items to dispatch
            end

            render json: { message: "#{items_count} item(s) moved to dispatch" }
          end
        end

        private

        def filter_demos
          dc_ids = @distribution_center.present? ? [@distribution_center.id] : current_user.distribution_centers.pluck(:id)
          @demos = Demo.dc_filter(dc_ids).where(is_active: true).order('id desc')

          @demos = @demos.where(tag_number: params[:tag_number].split_with_gsub) if params[:tag_number].present?
          @demos = @demos.where(sku_code: params[:sku_code].split_with_gsub) if params[:sku_code].present?
        end

        def get_demos
          @demos = Demo.where(id: params[:ids], is_active: true)
          raise 'Invalid ID.' and return if @demos.blank?
        end
      end
    end
  end
end
