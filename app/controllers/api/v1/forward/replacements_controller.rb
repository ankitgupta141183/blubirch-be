# frozen_string_literal: true

module Api
  module V1
    module Forward
      class ReplacementsController < ApplicationController
        before_action :get_replacements, only: %i[un_reserve get_payment_details set_disposition]

        def index
          set_pagination_params(params)
          filter_replacements

          @replacements = @replacements.page(@current_page).per(@per_page)
          render_collection(@replacements, Api::V1::Forward::ForwardReplacementSerializer)
        end

        def show
          @replacement = ForwardReplacement.find(params[:id])
          render_resource(@replacement, Api::V1::Forward::ForwardReplacementSerializer)
        end

        def item_details
          dc_ids = current_user.distribution_centers.pluck(:id)
          replacements = ForwardReplacement.dc_filter(dc_ids).where(is_active: true, status: 'In Stock', sku_code: params[:id])
          raise CustomErrors, 'Invalid Article ID' if replacements.blank?

          details = {
            per_unit_price: replacements.first.item_price.to_f,
            quantity: replacements.count
            # total_price: replacements.sum(:item_price).to_f
          }
          render json: details
        end

        def get_buyers
          query = params['query']
          buyers = if query.present?
                     VendorMaster.where('vendor_name LIKE (?) OR vendor_phone LIKE (?)', "%#{query}%", "%#{query}%")
                   else
                     VendorMaster.all
                   end
          buyers = buyers.limit(100).select(:id, :vendor_name, :vendor_code, :vendor_phone)
          render json: { buyers: buyers }
        end

        def reserve
          ActiveRecord::Base.transaction do
            total_items = 0
            pending_payment_status = LookupValue.find_by(code: 'forward_replacement_status_pending_payment')
            params['reserve_items'].each do |item_details|
              article_id, quantity, selling_price, buyer_id = item_details
              quantity = quantity.to_i
              buyer = VendorMaster.find_by(id: buyer_id)

              raise 'Invalid Buyer' and return if buyer.blank?
              raise 'Please enter valid Selling Price' and return if selling_price.blank? || selling_price.to_f.negative?
              raise 'Please enter valid Quantity' and return if quantity.blank? || quantity <= 0

              dc_ids = current_user.distribution_centers.pluck(:id)
              replacements = ForwardReplacement.dc_filter(dc_ids).where(is_active: true, status: 'In Stock', sku_code: article_id).order('id asc')
              raise 'Invalid Article ID.' and return if replacements.blank?
              raise "Available Quantity for Article ID #{article_id} is #{replacements.count}" and return if replacements.count < quantity

              replacements.limit(quantity).each do |replacement|
                replacement.reserve_item(buyer, pending_payment_status, selling_price)

                replacement.update_inventory_status(pending_payment_status, current_user.id)
              end
              total_items += quantity
            end
            render json: { message: "#{total_items} item(s) reserved successfully and moved to Pending Payment" }
          end
        end

        def reserve_items
          ActiveRecord::Base.transaction do
            pending_payment_status = LookupValue.find_by(code: 'forward_replacement_status_pending_payment')
            params['reserve_items'].each do |item_details|
              id, selling_price, buyer_id = item_details
              buyer = VendorMaster.find_by(id: buyer_id)
              replacement = ForwardReplacement.where(is_active: true, status: 'In Stock').find_by(id: id)

              raise 'Invalid ID' and return if replacement.blank?
              raise 'Invalid Buyer' and return if buyer.blank?
              raise 'Please enter valid Selling Price' and return if selling_price.blank? || selling_price.to_f.negative?

              replacement.reserve_item(buyer, pending_payment_status, selling_price)

              replacement.update_inventory_status(pending_payment_status, current_user.id)
            end
            render json: { message: "#{params['reserve_items'].count} item(s) reserved successfully and moved to Pending Payment" }
          end
        end

        def get_dispositions
          lookup_key = LookupKey.find_by(code: 'FORWARD_DISPOSITION')
          dispositions = lookup_key.lookup_values.where(original_code: ['Saleable', 'Production', 'Usage', 'Demo', 'Capital Assets']).as_json(only: %i[id original_code])
          render json: { dispositions: dispositions }
        end

        def set_disposition
          ActiveRecord::Base.transaction do
            disposition = LookupValue.find_by(id: params[:disposition_id])
            raise CustomErrors, "Disposition can't be blank" if disposition.blank?
            raise CustomErrors, 'Selected disposition is under development!' unless ['Saleable', 'Demo', 'Capital Assets'].include? disposition.original_code

            items_count = @replacements.count
            @replacements.each do |replacement|
              replacement.set_disposition(disposition.original_code, current_user)
            end

            render json: { message: "#{items_count} item(s) moved to #{disposition.original_code} disposition" }
          end
        end

        def un_reserve
          ActiveRecord::Base.transaction do
            in_stock_status = LookupValue.find_by(code: 'forward_replacement_status_in_stock')

            items_count = @replacements.count
            @replacements.each do |replacement|
              raise CustomErrors, 'Partially paid items can not be unreserved.' unless replacement.payment_status_pending?

              replacement.status_id = in_stock_status.id
              replacement.status = in_stock_status.original_code
              replacement.save!

              replacement.update_inventory_status(in_stock_status, current_user.id)
            end

            render json: { message: "#{items_count} item(s) moved back to In Stock" }
          end
        end

        def get_payment_details
          raise 'Pending and Partially Paid can not be paid together' and return if @replacements.pluck(:payment_status).uniq.count > 1

          get_total_amount_for_payment
          render json: { total_amount_to_be_paid: @total_amount_to_be_paid }
        end

        def update_payment_details
          ActiveRecord::Base.transaction do
            replacement = ForwardReplacement.where(is_active: true, status: 'Pending Payment').find(params[:id])
            raise 'Invalid ID.' and return if replacement.blank?

            total_amount_to_be_paid = to_rounded(replacement.selling_price.to_f - replacement.payment_received.to_f)

            raise 'Enter valid amount' and return if total_amount_to_be_paid.negative?
            raise "Payment received can't be blank or less than zero" and return if params['payment_received'].to_f.negative?
            raise "Payment received can't be more than #{total_amount_to_be_paid}" and return if params['payment_received'].to_f > total_amount_to_be_paid

            replacement.payment_received = replacement.payment_received.to_f + params['payment_received'].to_f
            if replacement.payment_received == replacement.selling_price
              replacement.payment_status = :paid
              replacement.is_active = false
              message = 'Item moved to dispatch.'
              # TODO: move to dispatch
            else
              replacement.payment_status = :partially_paid
              message = 'Partial payment received for this Item'
            end
            replacement.save!
            replacement.create_payment_history(current_user, params['payment_received'].to_f)

            render json: { message: message }
          end
        end

        private

        def filter_replacements
          status = params[:status] || 'In Stock'
          dc_ids = @distribution_center.present? ? [@distribution_center.id] : current_user.distribution_centers.pluck(:id)
          @replacements = ForwardReplacement.includes(:forward_inventory).dc_filter(dc_ids).where(status: status, is_active: true, payment_status: [1, 2]).order('updated_at desc')

          @replacements = @replacements.where(tag_number: params[:tag_number].split_with_gsub) if params[:tag_number].present?
          @replacements = @replacements.where(sku_code: params[:sku_code].split_with_gsub) if params[:sku_code].present?
        end

        def get_replacements
          @replacements = ForwardReplacement.where(id: params[:ids], is_active: true)
          raise 'Invalid ID.' and return if @replacements.blank?
        end

        def get_total_amount_for_payment
          @total_amount_to_be_paid = to_rounded(@replacements.sum(:selling_price) - @replacements.sum(:payment_received))
        end
      end
    end
  end
end
