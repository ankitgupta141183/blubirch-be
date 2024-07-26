# frozen_string_literal: true

module Api
  module V1
    module Warehouse
      module ReturnInitiation
        class ReversePickupController < ApplicationController
          before_action :get_pending_packaging_items, only: %i[index update_tag_numbers update_packaging_details]
          before_action :get_reverse_pickup_items, only: [:reverse_pickup_items]
          before_action :get_return_items, only: %i[update_pickup_date assign_logistic_partner update_pickup_details]

          def index
            set_pagination_params(params)
            filter_return_items

            @return_items = @return_items.page(@current_page).per(@per_page)
            render json: @return_items, meta: pagination_meta(@return_items)
          end

          # {items: [{sku_code: "238933", serial_number: "944665", tag_number: "t-242468"}]}
          def update_tag_numbers
            ActiveRecord::Base.transaction do
              params[:items].each do |item|
                return_item = @return_items.where(sku_code: item[:sku_code], serial_number: item[:serial_number]).first
                raise CustomErrors, 'Invalid Article ID or Serial Number' if return_item.blank?
                raise CustomErrors, "Tag number already updated for this Article ID #{return_item.sku_code}" if return_item.tag_number.present?

                existing_items = Item.where(tag_number: item[:tag_number])
                raise CustomErrors, 'Tag number is already taken.' if existing_items.present?

                return_item.tag_number = item[:tag_number]
                return_item.save!
              end
              render json: { message: 'Tag IDs updated successfully' }
            end
          end

          # {boxes: [{box_number: "B-2478", tag_numbers: ["t-242468", "t-097751"]}]}
          def update_packaging_details
            ActiveRecord::Base.transaction do
              params[:boxes].each do |box|
                tag_numbers = box[:tag_numbers]
                return_items = @return_items.where(tag_number: tag_numbers)
                raise CustomErrors, 'Invalid Tag ID' if tag_numbers.blank? || return_items.blank? || return_items.count != tag_numbers.size

                return_items.each do |return_item|
                  return_item.box_number = box[:box_number]
                  return_item.status_id = @reverse_pickup_status.id
                  return_item.status = @reverse_pickup_status.original_code
                  return_item.get_delivery_location
                  return_item.save!
                end
              end
              render json: { message: "Moved to 'Pending Reverse Pick Up'" }
            end
          end

          def reverse_pickup_items
            set_pagination_params(params)
            filter_return_items

            @return_items = @return_items.page(@current_page).per(@per_page)
            render json: @return_items, meta: pagination_meta(@return_items)
          end

          def update_pickup_date
            ActiveRecord::Base.transaction do
              raise CustomErrors, 'Please select Suggested Pick Up Date' if params[:pickup_date].blank?

              @return_items.update_all(suggested_pickup_date: params[:pickup_date])

              render json: { message: 'Successfully updated suggested pick up date' }
            end
          end

          def assign_logistic_partner
            ActiveRecord::Base.transaction do
              raise CustomErrors, 'Please enter Logistic Partner' if params[:logistic_partner].blank?

              @return_items.update_all(logistic_partner: params[:logistic_partner])

              render json: { message: 'Successfully assigned logistic partner' }
            end
          end

          def update_pickup_details
            ActiveRecord::Base.transaction do
              raise CustomErrors, 'Please enter Pickup Details' if params[:actual_pickup_date].blank? || params[:document_number].blank?

              pickup_closed_status = LookupValue.find_by(code: 'return_creation_status_reverse_pickup_closed')
              @return_items.each do |return_item|
                raise CustomErrors, 'Please assign Logistic Partner' if return_item.logistic_partner.blank?
                raise CustomErrors, 'Please update suggested pick up date' if return_item.suggested_pickup_date.blank?

                return_item.assign_attributes({
                                                actual_pickup_date: params[:actual_pickup_date], dispatch_document_number: params[:document_number], boxes_to_pickup: params[:boxes_to_pickup],
                                                actual_boxes_picked: params[:actual_boxes_picked], status_id: pickup_closed_status.id, status: pickup_closed_status.original_code
                                              })
                return_item.ird_number = ReturnItem.generate_ird if return_item.item_location == 'Customer'
                return_item.save!
              end
              flg, details = Item.inward_return_items(@return_items, Client.first.id)
              if flg
                render json: { message: 'Successfully updated and moved to PRD' }
              else
                render json: { error: 'Invalid Record', details: details }, status: :internal_server_error
                raise ActiveRecord::Rollback
              end
            end
          end

          def import_dc_locations
            DcLocation.import_dc_locations(params[:file])

            render json: { message: 'DC Locations imported successfully.' }
          end

          private

          def get_pending_packaging_items
            @pending_packaging_status = LookupValue.find_by(code: 'return_creation_status_pending_packaging')
            @reverse_pickup_status = LookupValue.find_by(code: 'return_creation_status_pending_reverse_pickup')
            @reverse_pickup_disposition = LookupValue.find_by(code: Rails.application.credentials.return_initiation_disposition_status_reverse_pickup)
            @return_items = ReturnItem.where(status_id: @pending_packaging_status&.id, disposition_id: @reverse_pickup_disposition&.id).order(updated_at: :desc)
          end

          def get_reverse_pickup_items
            @reverse_pickup_status = LookupValue.find_by(code: 'return_creation_status_pending_reverse_pickup')
            @reverse_pickup_disposition = LookupValue.find_by(code: Rails.application.credentials.return_initiation_disposition_status_reverse_pickup)
            @return_items = ReturnItem.where(status_id: @reverse_pickup_status&.id, disposition_id: @reverse_pickup_disposition&.id).order(updated_at: :desc)
          end

          def get_return_items
            @return_items = ReturnItem.where('id in (?)', params[:return_ids])
            raise CustomErrors, 'Invalid ID.' if @return_items.blank?
          end

          def filter_return_items
            @return_items = @return_items.where(return_sub_request_id: params[:search].to_s.gsub(' ', '').split(',')) if params[:search].present?
            @return_items = @return_items.where(irrd_number: params[:irrd_number].to_s.gsub(' ', '').split(',')) if params[:irrd_number].present?
            @return_items = @return_items.where(sku_code: params[:sku_code]) if params[:sku_code].present?
            @return_items = @return_items.where(return_type_id: params[:return_type].to_i) if params[:return_type].present?
            @return_items = @return_items.where('lower(item_location) = ? OR location_id = ?', params[:pickup_location].downcase, params[:pickup_location]) if params[:pickup_location].present?
            @return_items = @return_items.where(delivery_location_id: params[:delivery_location].to_i) if params[:delivery_location].present?
          end
        end
      end
    end
  end
end
