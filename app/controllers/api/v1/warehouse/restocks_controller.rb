# frozen_string_literal: true

module Api
  module V1
    module Warehouse
      class RestocksController < ApplicationController
        before_action -> { set_pagination_params(params) }, only: %i[index restock_dispatch_items]

        before_action :restocks_data, :search_by_tag_number, :search_by_item_price, :search_by_grade, :search_by_category, only: %i[index get_filters_data]

        before_action :get_restock, only: :show

        before_action :get_dispatch_items, only: :restock_dispatch_items
        before_action :search_items_by_tag_number, only: :restock_dispatch_items

        before_action :get_restocks, only: :create_restock_dispatch_order

        before_action :get_dispatch_item, only: :restock_dispatch_item

        # ^ GET /api/v1/warehouse/restocks
        def index
          # & Applying pagination
          @restocks = @restocks.page(@current_page).per(@per_page)

          # & Rendering data
          render_collection(@restocks, Api::V1::Warehouse::RestockSerializer)
        end

        # ^ GET /api/v1/warehouse/restocks/1
        def show
          # & Rendering Restock Data
          render json: @restock
        end

        # ^ GET /api/v1/warehouse/restocks/get_master_vendor
        def get_master_vendor
          # @vendor_master = VendorMaster.joins(:vendor_types).where('vendor_types.vendor_type': ["Restock", "Internal Vendor"]).where.not(vendor_code: current_user.distribution_centers.pluck(:code)).distinct
          # render json: @vendor_master
          @vendor_masters = if params[:query].present?
                              VendorMaster.joins(:vendor_types)
                                          .where.not(vendor_code: current_user.distribution_centers.pluck(:code))
                                          .where('lower(vendor_name) LIKE ? OR lower(vendor_code) LIKE ?', "%#{params[:query].to_s.downcase}%", "%#{params[:query].to_s.downcase}%")
                                          .distinct.limit(10)
                            else
                              VendorMaster.joins(:vendor_types).where.not(vendor_code: current_user.distribution_centers.pluck(:code)).distinct.limit(10)
                            end
          render json: @vendor_masters
        end

        # ^ GET /api/v1/warehouse/restocks/get_filters_data
        def get_filters_data
          grades = [{ id: 'A', name: 'A' }, { id: 'B', name: 'B' }, { id: 'C', name: 'C' }, { id: 'D', name: 'D' }, { id: 'AA', name: 'AA' }, { id: 'Not Tested', name: 'Not Tested' }]
          categories = @restocks.pluck(:category).compact.uniq.map { |name| { id: name, name: name } }
          min = @restocks.pluck(:item_price).compact.min
          max = @restocks.pluck(:item_price).compact.max
          render json: { grades: grades, categories: categories, min: min, max: max }
        end

        # ^ GET /api/v1/warehouse/restocks/restock_dispatch_items
        def restock_dispatch_items
          if @warehouse_order_items.present?
            @warehouse_order_items = @warehouse_order_items.page(@current_page).per(@per_page)
            render json: @warehouse_order_items, each_serializer: Api::V1::Warehouse::Wms::WarehouseOrderItemSerializer, meta: pagination_meta(@warehouse_order_items)
          else
            # @warehouse_order_items = @warehouse_order_items.page(@current_page).per(@per_page)
            render json: @warehouse_order_items, meta: pagination_meta(@warehouse_order_items)
          end
        end

        # ^ GET /api/v1/warehouse/restocks/restock_dispatch_item
        def restock_dispatch_item
          # & Rendering Restock Data
          render json: @warehouse_order_item, serializer: Api::V1::Warehouse::Wms::WarehouseOrderItemSerializer
        end

        def create_restock_dispatch_order
          if @restocks.blank? || params[:vendor_code].blank?
            render json: 'Please Provide Valid Inputs', status: :unprocessable_entity
          else
            ActiveRecord::Base.transaction do
              # & -- Step-1 --
              create_transfer_order

              # & -- Step-2 --
              create_dispatch_order

              # & -- Step 3 & 4 ---
              create_dispatch_order_items

              render json: { message: "#{@restocks.count} item(s) moved to Dispatch Successfully. " }
            end
          end
        end

        private

        # ^ ---------- Restock Record(s) from id ----------
        def get_restock
          @restock = Restock.find(params[:id])
        end

        def get_restocks
          @restocks = Restock.where(id: params[:ids])
        end

        # ^ ------------ Restocks Collection with filters -------------
        def restocks_data
          @restocks = Restock.includes(:inventory).where(is_active: true, status: 'Pending Restock Destination').order('restocks.created_at desc')
        end

        def search_by_tag_number
          @restocks = @restocks.where(tag_number: params[:tag_number].to_s.gsub(' ', '').split(',')) if params[:tag_number].present?
        end

        def search_by_item_price
          return unless params['price_min'].present? && params['price_max'].present?
          raise CustomErrors, 'Min or Max cannot be negative' if params['price_min'].to_f.negative? || params['price_max'].to_f.negative?
          raise CustomErrors, 'Min cannot be greater than Max' if params['price_min'].to_f > params['price_max'].to_f

          @restocks = @restocks.where("((details ->> 'asp')::numeric >= ?) AND ((details ->> 'asp')::numeric <= ?)", params['price_min'].to_f, params['price_max'].to_f)
        end

        def search_by_grade
          @restocks = @restocks.where(grade: params[:grade]) if params[:grade].present?
        end

        def search_by_category
          @restocks = @restocks.where(category: params[:category]) if params[:category].present?
        end

        # ^ ------------ Create Dispatch Order Process ---------------------
        def create_transfer_order
          @transfer_order = TransferOrder.new(vendor_code: params[:vendor_code], order_number: "OR-RES-#{SecureRandom.hex(6)}")
          @transfer_order.save!
        end

        def create_dispatch_order
          inv = @restocks.first.inventory
          @warehouse_order_status = LookupValue.find_by(code: Rails.application.credentials.order_status_warehouse_pending_pick)
          @warehouse_order = @transfer_order.warehouse_orders.new(
            distribution_center_id: inv.distribution_center_id,
            vendor_code: params[:vendor_code],
            client_id: begin
              inv.client_id
            rescue StandardError
              nil
            end,
            total_quantity: @restocks.count,
            status_id: @warehouse_order_status&.id,
            reference_number: @transfer_order.order_number
          )
          @warehouse_order.save
        end

        def create_dispatch_order_items
          @restock_new_status = LookupValue.find_by(code: Rails.application.credentials.restock_status_pending_restock_dispatch)

          @restocks.each do |restock|
            restock.update!(
              status_id: @restock_new_status.id,
              status: @restock_new_status.original_code,
              transfer_order_id: @transfer_order.id
            )

            client_category = begin
              ClientSkuMaster.find_by(code: restock.sku_code).client_category
            rescue StandardError
              nil
            end

            @warehouse_order_item = @warehouse_order.warehouse_order_items.new(
              inventory_id: restock.inventory_id,
              client_category_id: begin
                client_category.id
              rescue StandardError
                nil
              end,
              client_category_name: begin
                client_category.name
              rescue StandardError
                ''
              end,
              sku_master_code: restock.sku_code,
              item_description: restock.item_description,
              tag_number: restock.tag_number,
              serial_number: begin
                restock.inventory.serial_number
              rescue StandardError
                ''
              end,
              quantity: 1,
              status: @warehouse_order_status&.original_code,
              status_id: @warehouse_order_status&.id,
              toat_number: restock.toat_number,
              aisle_location: restock.aisle_location,
              details: restock.inventory.details
            )
            @warehouse_order_item.save

            # & --- Step 4 ---
            restock.create_history(current_user)
          end
        end

        # ^ ------------ Dispatch Items Collection with filters -------------
        def get_dispatch_items
          warehouse_orders = WarehouseOrder.select(:id).where(orderable_type: 'TransferOrder')
          return @warehouse_order_items if warehouse_orders.blank?

          return if warehouse_orders.blank?

          @warehouse_order_items = WarehouseOrderItem.where.not(tab_status: %i[pending_disposition not_found_items]).where(warehouse_order_id: warehouse_orders.pluck(:id))&.order('updated_at desc')
        end

        def search_items_by_tag_number
          @warehouse_order_items = @warehouse_order_items.where(tag_number: params[:tag_number].to_s.gsub(' ', '').split(',')) if params[:tag_number].present?
        end

        # ^ ------------ Dispatch Item -----------------------------
        def get_dispatch_item
          @warehouse_order_item = WarehouseOrderItem.find(params[:id])
        end
      end
    end
  end
end
