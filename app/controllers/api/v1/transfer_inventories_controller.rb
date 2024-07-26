# frozen_string_literal: true

module Api
  module V1
    # transfering item from one location to other
    class TransferInventoriesController < ApplicationController
      # include WarehouseOrderCreator
      include ModelSelector
      before_action :filtering_params, only: :index
      def index
        render json: @inventories, each_serializer: TransferInventorySerializer, meta: pagination_meta(@inventories), root: 'inventories'
      end

      def dispositions_type
        common_response('Disposition Type', 200, :disposition_type, ['Forward Disposition', 'Reverse Disposition'])
      end

      def dispositions
        dispositions = if params[:disposition_type].to_s == 'Forward Disposition'
                         forward_lookup_key = LookupKey.find_by(code: 'FORWARD_DISPOSITION')
                         forward_lookup_key.lookup_values.where.not(original_code: ['Transfer']).select(:id, :original_code).order(:id)
                       else
                         revese_lookup_key = LookupKey.find_by(code: 'WAREHOUSE_DISPOSITION')
                         revese_lookup_key.lookup_values.where.not(original_code: ['Pending Transfer Out', 'Rental', 'Capital Asset']).select(:id, :original_code).order(:id)
                       end
        common_response('Disposition List', 200, :dispositions, dispositions)
      end

      def dispositions_sub_status
        disposition_id = params[:disposition_id]
        respond_with_error('Please enter disposition') and return if disposition_id.blank?

        sub_statues = fetch_status(disposition_id)
        respond_with_error('No sub stages are found by provided dispostion') and return if sub_statues.blank?

        common_response('Sub statuses list', 200, :statuses, sub_statues)
      end

      def transfer_inventories
        disposition_type = params[:disposition_type].to_s
        respond_with_error('Please select Disposition Type.') and return if disposition_type.blank?

        ids = params[:ids]
        respond_with_error('Please select at least 1 inventory to transfer.') and return if ids.blank?

        model = if disposition_type == 'Forward Inventory'
                  ForwardInventory
                else
                  Inventory
                end
        inventories = model.where(id: ids)
        respond_with_error('Please select at least 1 inventory to transfer.') and return if inventories.blank?

        begin
          ActiveRecord::Base.transaction do
            inventories.each do |inv|
              is_vendor = if inv.is_a? Inventory
                            VendorMaster.find_by(vendor_code: inv.details['vendor_code'])
                          else
                            inv.vendor
                          end
              raise CustomErrors, "Vendor is not present for tag_number #{inv.tag_number}." if is_vendor.blank?

              inv.details['remarks'] = params[:remarks]
              inv.details['destination_id'] = params[:distribution_center_id]
              inv.details['transfer_vendor_id'] = is_vendor&.id
              inv.save
              bucket = inv.get_current_bucket
              raise "Bucket not found for selected tag number #{inv.tag_number}" if bucket.blank?
              raise "#{inv.tag_number} is already in Dispatch" if inv.disposition == 'Dispatch'
              bucket.update(is_active: false)
              @transfer_inventory = TransferInventory.create_record(inv, current_user)
              create_transfer_orders
              create_warehouse_order
              create_warehouse_order_items
            end
          end
        rescue StandardError => e
          return render_error(e.message, :unprocessable_entity)
        end
        # create_warehouse_order(bucket, inv)
        common_response("Successfully moved #{ids.count} item(s) to dispatch")
      end

      private

      def filtering_params
        set_pagination_params(params)
        distribution_center_id = params[:distribution_center_id]
        respond_with_error('Location id must be pass.') and return if distribution_center_id.blank?

        disposition_type = params[:disposition_type].to_s
        is_forward = disposition_type == 'Forward Disposition'
        disposition = params[:disposition]
        status = params[:status]
        search = params[:search]
        tag_numbers = params[:tag_numbers]
        article_ids = params[:article_ids]

        # Filters for tag numbers and article ids
        filter = {}
        filter.merge!({ tag_number: tag_numbers }) if tag_numbers.present?

        # find_model is used for finding appropriate model based on Dispostions
        klass = find_class(disposition, is_forward)
        table_name = klass.table_name

        # As Rental, Saleable and Capital Assets has Article SKU in db, we need to changed query
        if [Rental, Saleable, CapitalAsset].include?(klass)
          qry_search = ["#{table_name}.tag_number in (?) OR #{table_name}.article_sku in (?)", search, search] if search.present?
          filter.merge!({ article_sku: article_ids }) if article_ids.present?
        else
          filter.merge!({ sku_code: article_ids }) if article_ids.present?
          qry_search = ["#{table_name}.tag_number in (?) OR #{table_name}.sku_code in (?)", search, search] if search.present?
        end

        # dispostion query
        disposition_qry =  if is_forward.present?
          "forward_inventories.disposition <> 'Dispatch'"
        else
          "inventories.disposition <> 'Dispatch'"
        end
        # Distribustion center query and status query if pass
        qry = { distribution_center_id: distribution_center_id }
        qry.merge!({ is_active: true  }) if disposition.present?
        status = klass.bind_status_look_values[status] if status.present? && klass.eql?(BrandCallLog)
        qry.merge!({ status: status }) if status.present?

        if disposition.present?
          klass = if [ForwardReplacement, Demo].include?(klass)
                    klass.joins(:forward_inventory).includes(forward_inventory: %i[client_category distribution_center sub_location])
                  else
                    klass.joins(:inventory).includes(inventory: %i[client_category distribution_center sub_location])
                  end
          @inventories = klass.where(qry_search).where(qry).where(filter).page(@current_page).per(@per_page)
        else
          @inventories = if is_forward.present?
            ForwardInventory.includes(:client_category, :distribution_center,
                                              :sub_location).where(client_id: Client.first.id).where(disposition_qry).where(qry_search).where(qry).where(filter).page(@current_page).per(@per_page)
          else
            Inventory.includes(:client_category, :distribution_center,
                                              :sub_location).where(client_id: Client.first.id).where(disposition_qry).where(qry_search).where(qry).where(filter).page(@current_page).per(@per_page)
          end
        end
      end

      def find_class(disposition, is_forward)
        if disposition.present?
          find_model(disposition, is_forward)
        elsif is_forward.present?
          ForwardInventory
        else
          Inventory
        end
      end

      def create_transfer_orders
        vendor_master = @transfer_inventory.vendor_master
        @transfer_order = TransferOrder.new(vendor_code: vendor_master.vendor_code)
        @transfer_order.order_number = "OR-TransferInventory-#{SecureRandom.hex(6)}"
        @transfer_order.save!

        @transfer_inventory.update!(transfer_order_id: @transfer_order.id)
      end

      def create_warehouse_order
        @warehouse_order_status = LookupValue.find_by(code: Rails.application.credentials.dispatch_status_pending_pickup)
        @warehouse_order = @transfer_order.warehouse_orders.new(
          distribution_center_id: @transfer_inventory.receving_location_id,
          vendor_code: @transfer_order.vendor_code,
          reference_number: @transfer_order.order_number,
          client_id: @transfer_inventory.inventoryable.client_id,
          status_id: @warehouse_order_status.id,
          total_quantity: 1
        )
        @warehouse_order.save!
      end

      def create_warehouse_order_items
        @transfer_order.transfer_inventories.each do |transfer_inventory|

          inventory = transfer_inventory.inventoryable
          client_category = begin
            ClientSkuMaster.find_by(code: inventory.sku_code).client_category
          rescue StandardError
            nil
          end
          @warehouse_order_item = @warehouse_order.warehouse_order_items.new(
            client_category_id: begin
              client_category.id
            rescue StandardError
              nil
            end,
            client_category_name: begin
              client_category.name
            rescue StandardError
              nil
            end,
            sku_master_code: transfer_inventory.article_id,
            item_description: inventory.item_description,
            tag_number: inventory.tag_number,
            quantity: 1,
            status_id: @warehouse_order_status.id,
            status: @warehouse_order_status.original_code,
            serial_number: inventory.serial_number,
            details: inventory.details
          )
          if inventory.is_a? ForwardInventory
            @warehouse_order_item.forward_inventory_id = inventory.id
          else
            @warehouse_order_item.inventory_id = inventory.id
          end
          @warehouse_order_item.save!
        end
      end

      # def create_warehouse_order(bucket, inventory)

      #   case bucket.class.to_s
      #   when 'Insurance'
      #     create_insurance_warehouse_order(bucket, inventory)
      #   when 'Liquidation'
      #     # TODO, Need lot information
      #     # create_liquidation_warehouse_order(bucket, inventory)
      #   when 'Markdown'
      #     create_markdown_warehouse_order(bucket, inventory)
      #   when 'Redeploy'
      #     # TODO, Need lot information
      #     # create_redeploy_warehouse_order(bucket, inventory)
      #   when 'transfer_inventory'
      #     create_transfer_inventory_warehouse_order(bucket, inventory)
      #   when 'Replacement'
      #     create_replacement_warehouse_order(bucket, inventory)
      #   when 'VendorReturn'
      #     # TODO, get current bucket is not added for VendorReturn, as it Brand Call log, Brand Call log
      #     # not have warehouse orders
      #     # create_vendor_return_warehouse_order(bucket, inventory)
      #   end
      # end
    end
  end
end
