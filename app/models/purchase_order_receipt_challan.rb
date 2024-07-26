class PurchaseOrderReceiptChallan < ApplicationRecord

  belongs_to :oms_item, class_name: 'OrderManagementItem'
  belongs_to :oms, class_name: 'OrderManagementSystem'

  enum status: { 'pending': 'pending', 'closed': 'closed', 'cancelled': 'cancelled' }, _prefix: true

  validates_presence_of :rc_date, :rc_number, :item_type, :sku_code, :item_description, :price, :quantity, :status

  def self.create_rc(oms_id:, items:)
    begin
      ActiveRecord::Base.transaction do
        oms_items = OrderManagementItem.where(id: items.pluck(:id))
        raise "Items not found" if oms_items.blank?
        oms_ids = oms_items.pluck(:oms_id).compact.uniq
        raise "Receipt challan for multiple order cannot be created at same time" if oms_ids.count != 1 
        raise "Invalid Purchase Order" if oms_ids.first != oms_id
        grouped_items = oms_items.group_by{|item| item.id }
        rc_number = OrderManagementItem.rd_format('purchase_order')
        rc_items = []
        items.each do |item|
          next if item['quantity'].to_f <= 0.0
          order_item = grouped_items[item['id']].first
          item_quantity = order_item.quantity.to_f
          rc_total_quantity = order_item.purchase_order_receipt_challans.pluck(:quantity).compact.sum.to_f
          final_quantity = item_quantity - rc_total_quantity
          raise "Cannot create receipt challan for #{order_item.sku_code}" if final_quantity.to_f <= 0
    
          total_price = order_item.price.to_f * item['quantity'].to_f
          purchase_order_receipt_challan = PurchaseOrderReceiptChallan.create!(
            rc_date: Date.current, 
            rc_number: rc_number, 
            oms_item_id: item['id'],
            item_type: order_item.item_type,
            oms_id: order_item.oms_id,
            sku_code: order_item.sku_code,
            item_description: order_item.item_description,
            price: order_item.price,
            quantity: item['quantity'],
            total_price: total_price,
            status: 'pending'
          )
          rc_items << purchase_order_receipt_challan
        end
        rc_items
      end
    rescue => exe
      raise "#{exe.message} -> #{exe.backtrace}"
    end
  end

end
