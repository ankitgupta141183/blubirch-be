# frozen_string_literal: true

module WarehouseOrderCreator
  extend ActiveSupport::Concern

  def create_insurance_warehouse_order(bucket, inventory)
    ActiveRecord::Base.transaction do
      vendor_master = VendorMaster.find_by(vendor_code: inventory.details['vendor_code'])
      insurance_order = InsuranceOrder.new(vendor_code: vendor_master.vendor_code)
      insurance_order.order_number = "OR-Insurance-#{SecureRandom.hex(6)}"
      if insurance_order.save!
        # Update Vendor Return
        bucket.update(insurance_order_id: insurance_order.id)
        # Create Warehouse order
        warehouse_order_status = LookupValue.find_by(code: Rails.application.credentials.order_status_warehouse_pending_pick)
        warehouse_order = insurance_order.warehouse_orders.new(distribution_center_id: bucket.distribution_center_id, vendor_code: vendor_master, reference_number: insurance_order.order_number)
        warehouse_order.assign_attributes(client_id: inventory.client_id, status_id: warehouse_order_status.id, total_quantity: insurance_order.insurances.count)
        warehouse_order.save!

        # Create Warehouse Order Items
        insurance_order.insurances.each do |insurance|
          client_category = begin
            ClientSkuMaster.find_by(code: insurance.sku_code).client_category
          rescue StandardError
            nil
          end
          warehouse_order_item = warehouse_order.warehouse_order_items.new(
            inventory_id: insurance.inventory_id, client_category_id: client_category&.id, client_category_name: client_category&.name,
            sku_master_code: insurance.sku_code, item_description: insurance.item_description,
            tag_number: insurance.tag_number, quantity: 1, status_id: warehouse_order_status.id,
            serial_number: insurance.inventory.serial_number, aisle_location: insurance.aisle_location,
            toat_number: insurance.toat_number, details: insurance.inventory.details
          )
          warehouse_order_item.save!
        end
      end
    end
  end

  def create_liquidation_warehouse_order(bucket, inventory); end

  def create_markdown_warehouse_order(bucket, inventory)
    vendor_master = VendorMaster.find_by(vendor_code: inventory.details['vendor_code'])
    markdown_order = MarkdownOrder.new(vendor_code: vendor_master.vendor_code, order_number: "OR-PTO-#{SecureRandom.hex(6)}")
    if markdown_order.save!
      bucket.update(markdown_order_id: markdown_order.id)
      warehouse_order_status = LookupValue.find_by(code: Rails.application.credentials.order_status_warehouse_pending_pick)
      warehouse_order = markdown_order.warehouse_orders.new(client_id: inventory.client_id, distribution_center_id: inventory.distribution_center_id, status_id: warehouse_order_status.id,
                                                            total_quantity: 1, vendor_code: vendor_master.vendor_code)
      warehouse_order.save
      markdown_order.markdowns.each do |markdown|
        markdown_dispatch_complete_status = LookupValue.find_by(code: Rails.application.credentials.markdown_status_markdown_dispatch_complete)
        markdown.update(status_id: markdown_dispatch_complete_status.id, status: markdown_dispatch_complete_status.original_code, markdown_order_id: markdown_order.id, is_active: false)
        # Warehouse Order Item Creation
        client_category = inventory.client_category
        warehouse_order_item = warehouse_order.warehouse_order_items.new(inventory_id: inventory.id, sku_master_code: inventory.sku_code, item_description: inventory.item_description,
                                                                         tag_number: inventory.tag_number, quantity: 1, status_id: warehouse_order_status.id, status: warehouse_order_status.original_code, serial_number: inventory.serial_number, toat_number: markdown.toat_number)
        warehouse_order_item.client_category_id = begin
          client_category.id
        rescue StandardError
          nil
        end
        warehouse_order_item.client_category_name = begin
          client_category.name
        rescue StandardError
          nil
        end
        warehouse_order_item.aisle_location = begin
          markdown.aisle_location
        rescue StandardError
          nil
        end
        warehouse_order_item.details = inventory.details
        warehouse_order_item.save
        # Markdown History Creation
        markdown_history = markdown.markdown_histories.new(status_id: markdown.status_id)
        markdown_history.details = {}
        key = "#{markdown_dispatch_complete_status.original_code.try(:downcase).try(:strip).split(' ').join('_')}_created_at"
        markdown_history.details[key] = Time.zone.now
        markdown_history.details['status_changed_by_user_id'] = current_user.id
        markdown_history.details['status_changed_by_user_name'] = current_user.full_name
        markdown_history.save
      end
    end
  end

  # throwing error cause of validation
  def create_redeploy_warehouse_order(bucket, inventory)
    vendor_master = VendorMaster.find_by(vendor_code: inventory.details['vendor_code'])
    #-- Step-1 --
    redeploy_order = RedeployOrder.new(vendor_code: vendor_master.vendor_code, order_number: "OR-RED-#{SecureRandom.hex(6)}", lot_name: nil)
    redeploy_order.save!
    #-- Step-2 --
    #-----
    inv = inventory
    #-----
    warehouse_order                = redeploy_order.warehouse_orders.new(distribution_center_id: inv.distribution_center_id, vendor_code: vendor_master.vendor_code)
    warehouse_order_status         = LookupValue.find_by(code: Rails.application.credentials.order_status_warehouse_pending_pick)
    warehouse_order.client_id      = begin
      inv.client_id
    rescue StandardError
      nil
    end
    warehouse_order.status_id      = warehouse_order_status.id
    warehouse_order.total_quantity = 1
    warehouse_order.save
    original_code, status_id = LookupStatusService.new('Dispatch', 'pending_pick_and_pack').call
    redeploy = bucket
    redeploy.update(redeploy_order_id: redeploy_order.id)
    redeploy.update(status_id: status_id, status: original_code, redeploy_order_id: redeploy_order.id, is_active: false)
    #-- Step-3 --
    client_category = begin
      ClientSkuMaster.find_by(code: redeploy.sku_code).client_category
    rescue StandardError
      nil
    end
    warehouse_order_item                      = warehouse_order.warehouse_order_items.new
    warehouse_order_item.inventory_id         = redeploy.inventory_id
    warehouse_order_item.client_category_id   = begin
      client_category.id
    rescue StandardError
      nil
    end
    warehouse_order_item.client_category_name = begin
      client_category.name
    rescue StandardError
      ''
    end
    warehouse_order_item.sku_master_code      = redeploy.sku_code
    warehouse_order_item.item_description     = redeploy.item_description
    warehouse_order_item.tag_number           = redeploy.tag_number
    warehouse_order_item.serial_number        = begin
      redeploy.inventory.serial_number
    rescue StandardError
      ''
    end
    warehouse_order_item.quantity             = 1
    warehouse_order_item.status               = warehouse_order_status.original_code
    warehouse_order_item.status_id            = warehouse_order_status.id
    warehouse_order_item.toat_number          = redeploy.toat_number
    warehouse_order_item.aisle_location       = redeploy.aisle_location
    warehouse_order_item.details              = redeploy.inventory.details
    warehouse_order_item.save
    #-- Step-4 --
    details = { "#{original_code.try(:downcase).try(:strip).split(' ').join('_')}_created_at" => Time.zone.now,
                'status_changed_by_user_id' => current_user.id,
                'status_changed_by_user_name' => current_user.full_name }
    redeploy.redeploy_histories.create(status_id: status_id, details: details)
  end

  def create_repair_warehouse_order(bucket, inventory)
    vendor_master = VendorMaster.find_by(vendor_code: inventory.details['vendor_code'])
    repair_order = RepairOrder.new(vendor_code: vendor_master.vendor_code)
    repair_order.order_number = "OR-Repair-#{SecureRandom.hex(6)}"
    repair_order.save!
    bucket.update(repair_order_id: repair_order.id, tab_status: :dispatch, repair_status: :pending_dispatch_to_service_center)
    warehouse_order_status = LookupValue.find_by(code: Rails.application.credentials.dispatch_status_pending_pickup)
    warehouse_order = repair_order.warehouse_orders.new(
      distribution_center_id: bucket.distribution_center_id,
      vendor_code: repair_order.vendor_code,
      reference_number: repair_order.order_number,
      client_id: bucket.client_id,
      status_id: warehouse_order_status.id,
      total_quantity: repair_order.repairs.count
    )
    warehouse_order.save!

    repair_order.repairs.each do |repair|
      # & Creating repair history
      repair.create_history(current_user.id)
      # repair.update_inventory_status(next_status)

      client_category = begin
        ClientSkuMaster.find_by(code: repair.sku_code).client_category
      rescue StandardError
        nil
      end
      warehouse_order_item = warehouse_order.warehouse_order_items.new(
        inventory_id: repair.inventory_id,
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
        sku_master_code: repair.sku_code,
        item_description: repair.item_description,
        tag_number: repair.tag_number,
        quantity: 1,
        status_id: warehouse_order_status.id,
        status: warehouse_order_status.original_code,
        serial_number: repair.serial_number,
        aisle_location: repair.aisle_location,
        toat_number: repair.toat_number,
        details: repair.inventory.details,
        amount: repair.repair_amount
      )
      warehouse_order_item.save!
    end
  end

  def create_replacement_warehouse_order(bucket, inventory)
    replacement_order = ReplacementOrder.new(vendor_code: inventory.details['vendor_code'])
    replacement_order.order_number = "OR-Replacement-#{SecureRandom.hex(6)}"
    replacement_order.save!

    next_status = LookupValue.find_by(code: Rails.application.credentials.replacement_status_dispatch).original_code
    next_status_id = LookupValue.find_by(original_code: next_status).try(:id)
    bucket.update(replacement_order_id: replacement_order.id, status: next_status, status_id: next_status_id)

    warehouse_order_status = LookupValue.find_by(code: Rails.application.credentials.dispatch_status_pending_pickup)
    warehouse_order = replacement_order.warehouse_orders.new(
      distribution_center_id: bucket.distribution_center_id,
      vendor_code: replacement_order.vendor_code,
      reference_number: replacement_order.order_number,
      client_id: bucket.client_id,
      status_id: warehouse_order_status.id,
      total_quantity: replacement_order.replacements.count
    )
    warehouse_order.save!

    replacement_order.replacements.each do |replacement|
      # & Creating replacement history
      replacement.create_history(current_user.id)
      # repair.update_inventory_status(@next_status)

      client_category = begin
        ClientSkuMaster.find_by(code: replacement.sku_code).client_category
      rescue StandardError
        nil
      end
      warehouse_order_item = warehouse_order.warehouse_order_items.new(
        inventory_id: replacement.inventory_id,
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
        sku_master_code: replacement.sku_code,
        item_description: replacement.item_description,
        tag_number: replacement.tag_number,
        quantity: 1,
        status_id: warehouse_order_status.id,
        status: warehouse_order_status.original_code,
        serial_number: replacement.serial_number,
        aisle_location: replacement.aisle_location,
        toat_number: replacement.toat_number,
        details: replacement.inventory.details
      )
      warehouse_order_item.save!
    end
  end

  def create_vendor_return_warehouse_order(bucket, inventory)
    vendor_return = bucket
    ActiveRecord::Base.transaction do
      vendor_master = VendorMaster.find_by(vendor_code: inventory.details['vendor_code'])
      vendor_return_order = VendorReturnOrder.new(vendor_code: vendor_master.vendor_code, lot_name: nil)
      vendor_return_order.order_number = "OR-Brand-Call-Log-#{SecureRandom.hex(6)}"
      if vendor_return_order.save!
        original_code, status_id = LookupStatusService.new('Dispatch', 'pending_pick_and_pack').call
        # Update Vendor Return
        vendor_return.update(vendor_return_order_id: vendor_return_order.id, order_number: vendor_return_order.order_number, status_id: status_id, status: original_code)
        # Create Warehouse order
        warehouse_order_status = LookupValue.find_by(code: Rails.application.credentials.order_status_warehouse_pending_pick)
        warehouse_order = vendor_return_order.warehouse_orders.new(distribution_center_id: vendor_return.distribution_center_id, vendor_code: vendor_return_order.vendor_code,
                                                                   reference_number: vendor_return_order.order_number)
        warehouse_order.client_id = vendor_return.inventory.client_id
        warehouse_order.status_id = warehouse_order_status.id
        warehouse_order.total_quantity = 1
        warehouse_order.save!

        # Create Ware house Order Items
        vendor_return_order.vendor_returns.each do |vr|
          client_category = begin
            ClientSkuMaster.find_by(code: vr.sku_code).client_category
          rescue StandardError
            nil
          end
          warehouse_order_item = warehouse_order.warehouse_order_items.new
          warehouse_order_item.inventory_id = vr.inventory_id
          warehouse_order_item.aisle_location = vr.aisle_location
          warehouse_order_item.toat_number = vr.toat_number
          warehouse_order_item.client_category_id = begin
            client_category.id
          rescue StandardError
            nil
          end
          warehouse_order_item.client_category_name = begin
            client_category.name
          rescue StandardError
            nil
          end
          warehouse_order_item.sku_master_code = vr.sku_code
          warehouse_order_item.item_description = vr.item_description
          warehouse_order_item.tag_number = vr.tag_number
          warehouse_order_item.quantity = 1
          warehouse_order_item.status_id = warehouse_order_status.id
          warehouse_order_item.status = warehouse_order_status.original_code
          warehouse_order_item.details = vr.inventory.details
          warehouse_order_item.serial_number = vr.inventory.serial_number
          warehouse_order_item.save!
          details = { "#{original_code.try(:downcase).try(:strip).split(' ').join('_')}_created_at" => Time.zone.now,
                      'status_changed_by_user_id' => current_user.id,
                      'status_changed_by_user_name' => current_user.full_name }
          vr.vendor_return_histories.create(status_id: status_id, details: details)
        end
      end
    end
  end
end
