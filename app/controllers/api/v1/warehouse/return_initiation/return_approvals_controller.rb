# frozen_string_literal: true

module Api
  module V1
    module Warehouse
      module ReturnInitiation
        class ReturnApprovalsController < ApplicationController
          before_action :get_return_items, only: %i[approve_sales_return reject_sales_return approve_internal_return reject_internal_return approve_exchange_return approve_warranty_return approve_lease_return reject_return_item reject_warranty_return]
          before_action :get_pickup_status

          def index
            set_pagination_params(params)
            return_approval_status = LookupValue.find_by(code: Rails.application.credentials.return_creation_pending_approval_status)
            return_approval_disposition = LookupValue.find_by(code: Rails.application.credentials.return_initiation_disposition_status_return_approval)
            @return_approvals = ReturnItem.where(status_id: return_approval_status&.id, disposition_id: return_approval_disposition&.id).order(updated_at: :desc)

            filter_return_approvals

            @return_approvals = @return_approvals.page(@current_page).per(@per_page)
            render json: @return_approvals, meta: pagination_meta(@return_approvals)
          end

          def get_settlement_methods
            sales_return_key = LookupKey.find_by(code: Rails.application.credentials.sales_return_settlement_method)
            sales_return_reject_key = LookupKey.find_by(code: Rails.application.credentials.sales_return_reject_settlement_method)
            warranty_return_key = LookupKey.find_by(code: Rails.application.credentials.warranty_return_settlement_method)
            lease_return_key = LookupKey.find_by(code: Rails.application.credentials.lease_return_settlement_method)
            sales_return_settlement_methods = sales_return_key.lookup_values.order(id: :asc).as_json(only: %i[id original_code])
            sales_return_reject_settlement_methods = sales_return_reject_key.lookup_values.order(id: :asc).as_json(only: %i[id original_code])
            warranty_return_settlement_methods = warranty_return_key.lookup_values.order(id: :asc).as_json(only: %i[id original_code])
            lease_return_settlement_methods = lease_return_key.lookup_values.order(id: :asc).as_json(only: %i[id original_code])

            data = { sales_return_settlement_methods: sales_return_settlement_methods, sales_return_reject_settlement_methods: sales_return_reject_settlement_methods, warranty_return_settlement_methods: warranty_return_settlement_methods,
                     lease_return_settlement_methods: lease_return_settlement_methods, warranty_return_reject_settlement_methods: sales_return_reject_settlement_methods }
            render json: data
          end

          def get_enums_data
            item_decisions = ReturnItem.item_decisions.map { |k, v| { id: v, name: k.titleize } }
            repair_locations = ReturnItem.repair_locations.map { |k, v| { id: v, name: k.titleize } }
            movement_modes = ReturnItem.movement_modes.map { |k, v| { id: v, name: k.humanize } }
            internal_recovery_methods = ReturnItem.internal_recovery_methods.map { |k, v| { id: v, name: k.titleize } }

            render json: { item_decisions: item_decisions, repair_locations: repair_locations, movement_modes: movement_modes, internal_recovery_methods: internal_recovery_methods }
          end

          def approve_sales_return
            sales_return_key = LookupKey.find_by(code: Rails.application.credentials.sales_return_settlement_method)
            settlement_method = sales_return_key.lookup_values.find_by(id: params[:settlement_method_id])
            raise CustomErrors, 'Invalid Settlement Method' if settlement_method.blank?

            @return_items.each do |return_item|
              return_item.assign_attributes({
                                              settlement_method: settlement_method.original_code, settlement_method_id: settlement_method.id, refund_amount: params[:refund_amount].to_f,
                                              discount_amount: params[:discount_amount].to_f, movement_mode: params[:movement_mode], repair_location: params[:repair_location], remarks: params[:remarks],
                                              status_id: @reverse_pickup_status.id, status: @reverse_pickup_status.original_code, disposition_id: @reverse_pickup_disposition.id,
                                              disposition: @reverse_pickup_disposition.original_code, item_decision: params[:item_decision], approved_at: Time.zone.now, approved_by: current_user.id
                                            })
              raise CustomErrors, 'Discount amount should be lesser than actual amount.' if return_item.discount_amount > return_item.item_amount

              return_item.irrd_number = ReturnItem.generate_irrd
              return_item.ird_number = ReturnItem.generate_ird if return_item.item_location != 'Customer'
              return_item.save!
            end
            render json: { message: "Sales Return Successfully Approved for #{settlement_method.original_code}" }
          rescue Exception => e
            render json: { error: e.to_s }, status: :internal_server_error
          end

          def reject_sales_return
            sales_return_reject_key = LookupKey.find_by(code: Rails.application.credentials.sales_return_reject_settlement_method)
            settlement_method = sales_return_reject_key.lookup_values.find_by(id: params[:settlement_method_id])
            raise CustomErrors, 'Invalid Settlement Method' if settlement_method.blank?

            @return_items.each do |return_item|
              return_item.assign_attributes({
                                              settlement_method: settlement_method.original_code, settlement_method_id: settlement_method.id, repair_location: params[:repair_location], status_id: @reject_status.id,
                                              status: @reject_status.original_code, movement_mode: params[:movement_mode], rejected_at: Time.zone.now, rejected_by: current_user.id
                                            })
              return_item.save!
            end
            render json: { message: "Sales Return rejected with settlement method as #{settlement_method.original_code}" }
          rescue Exception => e
            render json: { error: e.to_s }, status: :internal_server_error
          end

          def approve_internal_return
            @return_items.each do |return_item|
              return_item.assign_attributes({
                                              item_decision: params[:item_decision], approved_at: Time.zone.now, approved_by: current_user.id, status_id: @reverse_pickup_status.id,
                                              status: @reverse_pickup_status.original_code, disposition_id: @reverse_pickup_disposition.id, disposition: @reverse_pickup_disposition.original_code
                                            })
              return_item.irrd_number = ReturnItem.generate_irrd
              return_item.ird_number = ReturnItem.generate_ird if return_item.item_location != 'Customer'
              return_item.save!
            end
            render json: { message: 'Internal Return Successfully Approved' }
          rescue Exception => e
            render json: { error: e.to_s }, status: :internal_server_error
          end

          def reject_internal_return
            vendor_master = VendorMaster.where('lower(vendor_name) = ? OR lower(vendor_code) = ?', params[:vendor_code], params[:vendor_code]).first
            raise CustomErrors, 'Invalid Vendor ID' if vendor_master.blank?

            internal_recovery_method = ReturnItem.internal_recovery_methods.invert[params[:recovery_method].to_i]
            raise CustomErrors, 'Please select Recovery Method' if internal_recovery_method.blank?

            @return_items.each do |return_item|
              return_item.assign_attributes({
                                              internal_recovery_method: params[:recovery_method], vendor_code: vendor_master.vendor_code, vendor_name: vendor_master.vendor_name,
                                              status_id: @reject_status.id, status: @reject_status.original_code, rejected_at: Time.zone.now, rejected_by: current_user.id
                                            })
              return_item.save!
            end
            render json: { message: "Internal Return successfully rejected with recovery method as #{internal_recovery_method.titleize}" }
          rescue Exception => e
            render json: { error: e.to_s }, status: :internal_server_error
          end

          def approve_exchange_return
            raise CustomErrors, 'Please enter revised amount.' if (params[:apply_revised_exchange_value] == true) && params[:revised_amount].blank?

            @return_items.each do |return_item|
              return_item.assign_attributes({
                                              item_decision: params[:item_decision], apply_revised_exchange_value: params[:apply_revised_exchange_value], revised_amount: params[:revised_amount].to_f,
                                              status_id: @reverse_pickup_status.id, status: @reverse_pickup_status.original_code, disposition_id: @reverse_pickup_disposition.id,
                                              disposition: @reverse_pickup_disposition.original_code, approved_at: Time.zone.now, approved_by: current_user.id
                                            })
              raise CustomErrors, 'Revised amount should be lesser than exchange value.' if return_item.revised_amount > return_item.item_amount

              return_item.irrd_number = ReturnItem.generate_irrd
              return_item.ird_number = ReturnItem.generate_ird if return_item.item_location != 'Customer'
              return_item.save!
            end
            render json: { message: 'Awaiting customer response on the revised exchange value.' }
          rescue Exception => e
            render json: { error: e.to_s }, status: :internal_server_error
          end

          def approve_warranty_return
            warranty_return_key = LookupKey.find_by(code: Rails.application.credentials.warranty_return_settlement_method)
            settlement_method = warranty_return_key.lookup_values.find_by(id: params[:settlement_method_id])
            raise CustomErrors, 'Invalid Settlement Method' if settlement_method.blank?

            @return_items.each do |return_item|
              return_item.assign_attributes({
                                              settlement_method: settlement_method.original_code, settlement_method_id: settlement_method.id, item_decision: params[:item_decision],
                                              repair_location: params[:repair_location], movement_mode: params[:movement_mode], spare_details: params[:spare_details],
                                              status_id: @reverse_pickup_status.id, status: @reverse_pickup_status.original_code, disposition_id: @reverse_pickup_disposition.id,
                                              disposition: @reverse_pickup_disposition.original_code, approved_at: Time.zone.now, approved_by: current_user.id
                                            })
              return_item.irrd_number = ReturnItem.generate_irrd
              return_item.ird_number = ReturnItem.generate_ird if return_item.item_location != 'Customer'
              return_item.save!
            end
            render json: { message: "Warranty Claim successfully approved for #{settlement_method.original_code}" }
          rescue Exception => e
            render json: { error: e.to_s }, status: :internal_server_error
          end

          def reject_warranty_return
            # Sales and Warranty rejections are similar
            warranty_return_reject_key = LookupKey.find_by(code: Rails.application.credentials.sales_return_reject_settlement_method)
            settlement_method = warranty_return_reject_key.lookup_values.find_by(id: params[:settlement_method_id])
            raise CustomErrors, 'Invalid Settlement Method' if settlement_method.blank?

            @return_items.each do |return_item|
              return_item.assign_attributes({
                                              settlement_method: settlement_method.original_code, settlement_method_id: settlement_method.id, repair_location: params[:repair_location], status_id: @reject_status.id,
                                              status: @reject_status.original_code, movement_mode: params[:movement_mode], rejected_at: Time.zone.now, rejected_by: current_user.id
                                            })
              return_item.save!
            end
            render json: { message: "Warranty Return rejected with settlement method as #{settlement_method.original_code}" }
          rescue Exception => e
            render json: { error: e.to_s }, status: :internal_server_error
          end

          def approve_lease_return
            lease_return_key = LookupKey.find_by(code: Rails.application.credentials.lease_return_settlement_method)
            settlement_method = lease_return_key.lookup_values.find_by(id: params[:settlement_method_id])
            raise CustomErrors, 'Invalid Settlement Method' if settlement_method.blank?

            @return_items.each do |return_item|
              return_item.assign_attributes({
                                              settlement_method: settlement_method.original_code, settlement_method_id: settlement_method.id, item_decision: params[:item_decision],
                                              lease_deduction_amount: params[:lease_deduction_amount].to_f, status_id: @reverse_pickup_status.id, status: @reverse_pickup_status.original_code,
                                              disposition_id: @reverse_pickup_disposition.id, disposition: @reverse_pickup_disposition.original_code, approved_at: Time.zone.now, approved_by: current_user.id
                                            })
              return_item.irrd_number = ReturnItem.generate_irrd
              return_item.ird_number = ReturnItem.generate_ird if return_item.item_location != 'Customer'
              return_item.save!
            end
            settlement_type = settlement_method.original_code.gsub('Approve', 'approved').downcase
            render json: { message: "Lease Return successfully #{settlement_type}" }
          rescue Exception => e
            render json: { error: e.to_s }, status: :internal_server_error
          end

          def reject_return_item
            @return_items.each do |return_item|
              return_item.assign_attributes({
                                              status_id: @reject_status.id, status: @reject_status.original_code, rejected_at: Time.zone.now, rejected_by: current_user.id
                                            })
              return_item.save!
            end
            render json: { message: "#{@return_items.last.return_type} rejected successfully" }
          rescue Exception => e
            render json: { error: e.to_s }, status: :internal_server_error
          end

          private

          def filter_return_approvals
            @return_approvals = @return_approvals.where(return_sub_request_id: params[:search].to_s.gsub(' ', '').split(',')) if params[:search].present?
            @return_approvals = @return_approvals.where(return_request_id: params[:return_request_id].to_s.gsub(' ', '').split(',')) if params[:return_request_id].present?
            @return_approvals = @return_approvals.where(return_type_id: params[:return_type].to_i) if params[:return_type].present?
          end

          def get_return_items
            @return_items = ReturnItem.where('id in (?)', params[:return_ids])
            raise CustomErrors, 'Invalid ID.' if @return_items.blank?
          end

          def get_pickup_status
            @reverse_pickup_status = LookupValue.find_by(code: 'return_creation_status_pending_packaging')
            @reverse_pickup_disposition = LookupValue.find_by(code: Rails.application.credentials.return_initiation_disposition_status_reverse_pickup)
            @reject_status = LookupValue.find_by(code: Rails.application.credentials.return_creation_closed_reject_status)
          end
        end
      end
    end
  end
end
