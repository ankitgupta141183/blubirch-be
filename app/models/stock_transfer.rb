class StockTransfer < ApplicationRecord
  acts_as_paranoid
  has_one :warehouse_order , as: :orderable 


  def self.transfer(selected_inventories, params)

    ActiveRecord::Base.transaction do
      stock_transfer_item = StockTransfer.create(vendor_code:params["destination"],order_number:"RSTO-#{SecureRandom.hex(3)}")
      inventory = nil
      distribution_center_id = nil
      first_inventory = Inventory.find(selected_inventories.first["id"])
      distribution_center_id = first_inventory.distribution_center_id
      warehouse_order_status = LookupValue.where("code = ?", Rails.application.credentials.order_status_warehouse_pending_pick).first
      warehouse_order = WarehouseOrder.create(orderable: stock_transfer_item,distribution_center_id: distribution_center_id , status_id: warehouse_order_status.id,vendor_code:params["destination"],total_quantity: params["selected_inventories"].count)
      client_sku_master = nil
      client_category_id = nil
      temp_details = nil
      
      selected_inventories.each do |i|
        inventory = Inventory.find(i["id"])
        #DispositionRule.create_bucket_record(inventory,params["disposition"])
        inventory.details["stock_transfer_order_number"] = stock_transfer_item.order_number
        inventory.details["stock_transfer_order_name"] = params["order_name"]
        inventory.details["stock_transfer_order_amount"] = params["amount"]
        temp_details = inventory.details
        inventory.update(details:inventory.details)
        client_sku_master = ClientSkuMaster.find_by(code: inventory.sku_code)
        client_category = ClientCategory.find(client_sku_master.client_category_id)
        distribution_center_id = inventory.distribution_center_id

        WarehouseOrderItem.create(warehouse_order_id: warehouse_order.id , inventory_id: inventory.id , tag_number: inventory.tag_number , serial_number: inventory.serial_number , status_id: warehouse_order_status.id, status: warehouse_order_status.original_code ,sku_master_code: inventory.sku_code ,client_category_id: client_category.id , client_category_name: client_category.name , details: temp_details , toat_number: inventory.toat_number ,item_description: inventory.item_description , aisle_location: inventory.aisle_location, quantity: inventory.quantity)
      end

     


      
    end 
  end
end
