# frozen_string_literal: true

module Api
  module V2
    module Warehouse
      class SaleablesController < ApplicationController
        before_action -> { set_pagination_params(params) }, only: :index
        before_action :get_saleables, :filters, only: %i[index reserve_items update_disposition un_reserve update_payment_details get_payment_details set_dispositions]
        before_action :get_saleable, only: [:show]

        # ^ GET - /api/v2/warehouse/saleables
        def index
          @saleables = @saleables.page(@current_page).per(@per_page)
          render_collection(@saleables, Api::V2::Warehouse::SaleableSerializer)
        end

        # ^ GET - /api/v2/warehouse/saleables/:id
        def show
          render_resource(@saleable, Api::V2::Warehouse::SaleableSerializer)
        end

        # ^ GET - /api/v2/warehouse/saleables/:article_id/item_details
        def item_details
          saleables = Saleable.where(is_active: true, status: 'In Stock', article_sku: params['id'])
          begin
            per_unit_price = saleables.first.selling_price.to_f
            total_price = saleables.pluck(:selling_price).compact.sum.to_f
          rescue StandardError
            per_unit_price, total_price = 0.0
          end
          details = {
            per_unit_price: per_unit_price,
            quantity: saleables.count,
            total_price: total_price,
            location: (saleables.first.location rescue '')
          }
          render json: details
        end

        # ^ GET - /api/v2/warehouse/saleables/get_buyers
        def get_buyers
          if params['query'].present?
            buyers = VendorMaster.where(
              'vendor_name LIKE (?) OR vendor_phone LIKE (?)', "%#{params['query']}%", "%#{params['query']}%"
            ).select(:id, :vendor_name, :vendor_code, :vendor_phone).limit(10)
          end
          buyers = VendorMaster.all.select(:id, :vendor_name, :vendor_code, :vendor_phone).limit(10) if params['query'].blank?
          render json: { buyers: buyers }
        end

        # ^ POST - /api/v2/warehouse/saleables/create_buyer
        def create_buyer
          ActiveRecord::Base.transaction do
            vendor_master = VendorMaster.new(buyer_permitted_params)
            vendor_master.vendor_code = VendorMaster.generate_code
            vendor_master.save!
            render_resource(vendor_master, nil)
          end
        rescue ActiveRecord::RecordInvalid => e
          render json: e.message, status: :unprocessable_entity
          nil
        end

        # ^ GET - /api/v2/warehouse/saleables/dispositions
        def dispositions
          lookup_key = LookupKey.find_by(code: 'FORWARD_DISPOSITION')
          dispositions = lookup_key.lookup_values.where(original_code: ['Rental', 'Production', 'Usage', 'Demo', 'Replacement', 'Capital Assets']).as_json(only: %i[id original_code])
          render json: { dispositions: dispositions }
        end

        # ^ POST - /api/v2/warehouse/saleables/set_dispositions
        def set_dispositions
          ActiveRecord::Base.transaction do
            disposition = LookupValue.find_by(id: params[:disposition_id])
            raise CustomErrors, "Disposition can't be blank" if disposition.blank?

            items_count = @saleables.count
            @saleables.each do |saleable|
              saleable.is_active = false
              saleable.save!
              
              DispositionRule.create_fwd_bucket_record(disposition.original_code, saleable.inventory, 'Saleable', current_user&.id)
            end

            render json: { message: "#{items_count} item(s) moved to #{disposition.original_code} disposition" }
          end
        end

        # ^ GET - /api/v2/warehouse/saleables/get_city_and_states
        def get_city_and_states
          states_and_cities = Saleable.state_and_cities
          render json: states_and_cities
        end

        # ^ PUT - /api/v2/warehouse/saleables/reserve_items
        def reserve_items
          ActiveRecord::Base.transaction do
            reserve_number = Saleable.generate_reserve_number
            params['reserve_items'].each do |item_details|
              article_id, quantity, selling_price, vendor_id = item_details

              raise 'Invalid Params' and break if article_id.blank? || (quantity.blank? || quantity.to_f <= 0) || selling_price.blank? || vendor_id.blank?

              saleables = Saleable.where(is_active: true, status: 'In Stock', article_sku: article_id).order('saleables.benchmark_date asc')
              raise "Quantity for article_id #{article_id} cannot be more than #{saleables.count}" and break if saleables.count < quantity.to_i

              next_status = LookupValue.find_by(code: 'saleable_status_pending_payment')
              quantity_count = 1
              saleables.each do |saleable|
                next if quantity_count > quantity.to_i

                saleable.vendor_id = vendor_id.to_i
                saleable.vendor_code = saleable.vendor.vendor_code
                saleable.vendor_name = saleable.vendor.vendor_name
                saleable.status = next_status.original_code
                saleable.status_id = next_status.id
                saleable.selling_price = selling_price
                saleable.reserve_date = Date.current
                saleable.reserve_number = reserve_number
                saleable.save!
                saleable.create_history(current_user.id)
                quantity_count += 1
              end
              inventory = ForwardInventory.find_by(sku_code: article_id)
              inventory.update_inventory_status(next_status)
            end
            render json: { message: "#{params['reserve_items'].count} item(s) Reserved Successfully and moved to Pending Payment" }
          end
        rescue ActiveRecord::RecordInvalid => e
          render json: e.message, status: :unprocessable_entity
          nil
        end

        # ^ PUT - /api/v2/warehouse/saleables/update_disposition
        def update_disposition
          # ! Will keep adding as other modules are done
        end

        # ^ PUT - /api/v2/warehouse/saleables/un_reserve
        def un_reserve
          ActiveRecord::Base.transaction do
            next_status = LookupValue.find_by(code: 'saleable_status_in_stock')
            inventory_ids = []
            items_count = @saleables.count
            @saleables.each do |saleable|
              raise 'Only record with no payment can be unreserve' and break unless saleable.payment_status_pending?

              inventory_ids << saleable.inventory_id
              saleable.reserve_date = nil
              saleable.reserve_number = nil
              saleable.status_id = next_status.id
              saleable.status = next_status.original_code
              saleable.vendor_id = nil
              saleable.vendor_code = nil
              saleable.vendor_name = nil
              saleable.save!
              saleable.create_history(current_user.id)
            end
            inventory_ids.uniq.each do |inv_id|
              inventory = ForwardInventory.find(inv_id)
              inventory.update_inventory_status(next_status)
            end
            render json: { message: "#{items_count} item(s) moved back to In Stock" }
          end
        rescue ActiveRecord::RecordInvalid => e
          render json: e.message, status: :unprocessable_entity
          nil
        end

        # ^ GET - /api/v2/warehouse/saleables/get_payment_details
        def get_payment_details
          raise 'Pending and Partial Paid cannot be paid together' and return if @saleables.pluck(:payment_status).uniq.count > 1
          raise 'Invalid Payment Status' and return if @saleables.pluck(:payment_status).uniq.first != 'partial_paid' && @saleables.pluck(:payment_status).uniq.first != 'pending'

          get_total_amount_for_payment
          render json: { total_amount_to_be_paid: @total_amount_to_be_paid }
        end

        # ^ PUT - /api/v2/warehouse/saleables/update_payment_details
        def update_payment_details
          ActiveRecord::Base.transaction do
            get_total_amount_for_payment
            raise 'payment_received cannot be blank or less than equal to zero' and return if params['payment_received'].to_f <= 0
            raise "payment_received cannot be more than #{@total_amount_to_be_paid}" and return if params['payment_received'].to_f > @total_amount_to_be_paid
            raise 'total_payment_amount does not match' and return if params['total_payment_amount'].to_f != @total_amount_to_be_paid.to_f
            raise 'total amount paid cannot be zero' and return if @total_amount_to_be_paid.to_f <= 0

            if to_rounded(@total_amount_to_be_paid.to_f) == to_rounded(params['payment_received'].to_f)
              payment_status = 'paid'
              inv_ids = []
              item_count = @saleables.count
              @saleables.each do |saleable|
                inv_ids << saleable.inventory_id
                total_paid_amount = to_rounded(saleable.selling_price) - to_rounded(saleable.payment_received.to_f)
                saleable.update!(payment_received: saleable.selling_price, payment_status: payment_status)
                saleable.create_payment_history(current_user, total_paid_amount)
              end
              Saleable.send_items_to_dispatch(@saleables.pluck(:id))
              @saleables.find_each { |saleable| saleable.update!(is_active: false) }
              render json: { message: "#{item_count} item(s) Payment Completed" }
            end
            if (@saleable_status = 'pending' && to_rounded(@total_amount_to_be_paid.to_f) > to_rounded(params['payment_received'].to_f))
              payment_status = 'partial_paid'
              percentage = to_rounded((params['payment_received'].to_f / @total_amount_to_be_paid) * 100.to_f)
              @saleables.each do |saleable|
                total_paid_amount = to_rounded((saleable.selling_price.to_f / 100) * percentage.to_f).round
                saleable.update!(payment_received: total_paid_amount, payment_status: payment_status)
                saleable.create_payment_history(current_user, total_paid_amount)
              end
              render json: { message: "#{@saleables.count} item(s) Partially Payment Done" }
            end
          end
        rescue ActiveRecord::RecordInvalid => e
          render json: e.message, status: :unprocessable_entity
          nil
        end

        private

        def get_saleables
          get_distribution_centers('Saleable')
          dc_ids = @distribution_center.present? ? [@distribution_center.id] : current_user.distribution_centers.pluck(:id)
          @status = params['status'].presence || 'In Stock'
          @ids = params['ids'].presence || Saleable.ids.join(',')
          @saleables = Saleable.dc_filter(dc_ids).where(status: @status, id: @ids.split_with_gsub, is_active: true).order('saleables.created_at DESC')
        end

        def filters
          @saleables = @saleables.where(tag_number: params['tag_number'].split_with_gsub) if params['tag_number'].present?
          @saleables = @saleables.where(article_sku: params['article_id'].split_with_gsub) if params['article_id'].present?
          @saleables = @saleables.where('article_sku IN (?)  OR  tag_number IN  (?)', params['query'].split_with_gsub, params['query'].split_with_gsub) if params['query'].present?
        end

        def get_saleable
          @saleable = Saleable.find(params[:id])
        end

        def get_total_amount_for_payment
          if @saleables.pluck(:payment_status).uniq.first == 'partial_paid'
            @total_amount_to_be_paid = to_rounded(@saleables.pluck(:selling_price).compact.sum - @saleables.pluck(:payment_received).compact.sum)
            @saleable_status = 'partial_paid'
          elsif @saleables.pluck(:payment_status).uniq.first == 'pending'
            @total_amount_to_be_paid = to_rounded(@saleables.pluck(:selling_price).compact.sum)
            @saleable_status = 'pending'
          else
            @total_amount_to_be_paid = 0
          end
        end

        def buyer_permitted_params
          params.require(:vendor_master).permit(:vendor_name, :vendor_email, :vendor_phone, :vendor_address, :vendor_city, :vendor_state)
        end
      end
    end
  end
end
