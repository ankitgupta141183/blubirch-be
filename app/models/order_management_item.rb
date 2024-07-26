class OrderManagementItem < ApplicationRecord
  has_many :order_management_items, as: :inventory, dependent: :destroy

  belongs_to :oms, class_name: 'OrderManagementSystem'
  belongs_to :inventory, polymorphic: true, optional: true
  has_many :purchase_order_receipt_challans, dependent: :destroy, foreign_key: 'oms_item_id'

  enum status: { 'pending': 'pending', 'closed': 'closed', 'cancelled': 'cancelled' }, _prefix: true

  validates_presence_of :rrd_creation_date, :reason_reference_document_no, :sku_code, :item_description, :price, :quantity, :total_price, :status

  #? OrderManagementItem.rd_format("purchase_order")
  def self.rd_format(order_type)
    order_types_hash = {
      "purchase_order" => "RC",
    }
    rd_number = order_types_hash[order_type]
    if rd_number.present?
      return "#{rd_number}#{rand(100000..999999)}"
    end
  end

  #? OrderManagementItem.create_items(oms_type:, order_id: , rrd_number: , item_params: )
  def self.create_items(oms_type:, order_id:, rrd_number:, item_params: )
    inv_hash = {}
    ClientSkuMaster.where(code: item_params.pluck(:sku_code)).select(:id, :code, :sku_description, :mrp).each { |inv| inv_hash[inv.code] = inv }
    raise 'No Inventory found' if inv_hash.blank?
    final_price = 0
    item_params.each do |item_data|
      inventory = inv_hash[item_data[:sku_code]]
      raise "No Inventory present for #{item_data[:sku_code]} sku_code" if inventory.blank?
      raise "Total Price does not match for #{item_data[:sku_code]} sku_code" if (item_data[:price].to_f * item_data[:quantity].to_f != item_data[:total_price].to_f)
      order_management_item = OrderManagementItem.find_or_initialize_by(oms_id: order_id, inventory: OrderManagementItem.last)
      order_management_item.assign_attributes({
        rrd_creation_date: Date.current,
        reason_reference_document_no: rrd_number,
        item_type: oms_type,
        sku_code: item_data[:sku_code],
        item_description: item_data[:item_description],
        price: item_data[:price],
        quantity: item_data[:quantity],
        total_price: item_data[:total_price],
        status: 'pending'
      })
      order_management_item.save!
      final_price = final_price.to_f + item_data[:price].to_f
    end
    OrderManagementSystem.find(order_id).update!(amount: final_price)
  end

  def create_invoice(invoice_data)
    remaining_quantity = self.quantity - invoice_data[:quantity]
    self.order_management_items.create!(self.as_json(only: [
      :rrd_creation_date,
      :reason_reference_document_no,
      :reference_document_no,
      :item_type,
      :oms_id,
      :tag_number,
      :sku_code,
      :item_description,
      :serial_number,
      :price,
      :status,
      :details
    ]).merge({
      total_price: self.price * remaining_quantity,
      quantity: remaining_quantity
    })) unless remaining_quantity.zero?
    update!(invoice_data)
  end

  def self.get_invoice_no(order_type)
    order_types_hash = {
      "purchase_order" => "RC",
      "sales_order" => "IN",
    }
    "#{order_types_hash[order_type]}#{rand(100000..999999)}"
  end
end
