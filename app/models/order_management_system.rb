class OrderManagementSystem < ApplicationRecord
  has_many :order_management_items, dependent: :destroy, foreign_key: 'oms_id'
  has_many :purchase_order_receipt_challans, dependent: :destroy, foreign_key: 'oms_id'
  belongs_to :billing_location, class_name: 'DistributionCenter'
  belongs_to :receiving_location, class_name: 'DistributionCenter'
  belongs_to :vendor, class_name: 'ClientProcurementVendor', optional: true

  enum status: { 'pending': 'pending', 'partially_closed': 'partially_closed', 'awaiting_approval': 'awaiting_approval', 'closed': 'closed', 'cancel': 'cancel' }, _prefix: true
  enum oms_type: { 'forward': 'forward', 'reverse': 'reverse' }, _prefix: true
  enum order_type: {"purchase_order"=>"purchase_order", "inward_transfer_order"=>"inward_transfer_order", "forward_repair_order"=>"forward_repair_order", "return_order"=>"return_order", "inward_replacement_order"=>"inward_replacement_order", "lease_procurement_order"=>"lease_procurement_order", "sales_order"=>"sales_order", "back_order"=>"back_order", "lease_order"=>"lease_order", "replacement_customer_order"=>"replacement_customer_order", "outward_return_order"=>"outward_return_order", "transfer_order"=>"transfer_order", "reverse_repair_order"=>"reverse_repair_order", "replacement_order"=>"replacement_order"}, _prefix: true

  FORWARD_ORDERS = %w[purchase_order inward_transfer_order forward_repair_order return_order inward_replacement_order lease_procurement_order]

  REVERSE_ORDERS = %w[sales_order back_order lease_order replacement_customer_order outward_return_order transfer_order reverse_repair_order replacement_order]

  validates_presence_of :rrd_creation_date, :reason_reference_document_no, :status, :order_reason, :oms_type, :order_type

  validate :validate_order_types

  default_scope { where.not(status: 'closed') }

  def self.create_order(oms_type:, order_type:, order_params:)
    begin
      ActiveRecord::Base.transaction do
        order_management = OrderManagementSystem.new(order_params.except("items"))
        order_management.oms_type = oms_type
        order_management.order_type = order_type
        order_management.status = 'pending'
        order_management.rrd_creation_date = Date.current
        order_management.reason_reference_document_no = OrderManagementSystem.rrd_format(order_type)
    
        #? Validate has_payment_terms
        if order_management.has_payment_terms?
          raise "Invalid keys for payment_term_details" if  order_management.payment_term_details.keys.sort != ["no_of_days", "per_in_advance", "per_on_credit", "per_on_delivery"]
        end
    
        #? Add vendor details
        if order_management.vendor.present?
          vendor = order_management.vendor
          order_management.vendor_details = {
            "vendor_code" => vendor.vendor_code,
            "vendor_name" => vendor.vendor_name,
            "vendor_type" => vendor.vendor_type
          }
        end
        
        #? Add Billing location details
        if order_management.billing_location.present?
          bl = order_management.billing_location
          order_management.billing_location_details = {
            "name" => bl.name,
            "code" => bl.code,
            "site_category" => bl.site_category,
            "city" => (bl.city.original_code rescue nil),
            "state" => (bl.state.original_code rescue nil),
            "country" => (bl.country.original_code rescue nil)
          }
        end
    
        #? Add Receiving location details
        if order_management.receiving_location.present?
          rl = order_management.receiving_location
          order_management.receiving_location_details = {
            "name" => rl.name,
            "code" => rl.code,
            "site_category" => rl.site_category,
            "city" => (rl.city.original_code rescue nil),
            "state" => (rl.state.original_code rescue nil),
            "country" => (rl.country.original_code rescue nil)
          }
        end
    
        order_management.save!
        OrderManagementItem.create_items(oms_type: oms_type, order_id: order_management.id, rrd_number:  order_management.reason_reference_document_no, item_params: order_params["items"])
        order_management
      end
    rescue => e
      raise "#{e.message} => #{e.backtrace}"
    end
  end

  #? OrderManagementSystem.rrd_format("purchase_order")
  def self.rrd_format(order_type)
    order_types_hash = {
      "purchase_order" => "PO",
      "inward_transfer_order" => "ITO",
      "forward_repair_order" => "FRO",
      "return_order" => "RTO",
      "inward_replacement_order" => "IRO",
      "lease_procurement_order" => "LPO",
      "sales_order" => "SO",
      "back_order" => "BO",
      "lease_order" => "LO",
      "replacement_customer_order" => "RCO",
      "outward_return_order" => "ORRD",
      "transfer_order" => "TO", 
      "reverse_repair_order" => "RRO",
      "replacement_order" => "RPO"
    }
    rrd_number = order_types_hash[order_type]
    if rrd_number.present?
      return "#{rrd_number}#{rand(100000..999999)}"
    end
  end
  
  def validate_order_types
    if self.oms_type_forward?
      raise "Invalid order type" if FORWARD_ORDERS.exclude?(self.order_type)
    elsif self.oms_type_reverse?
      raise "Invalid order type" if REVERSE_ORDERS.exclude?(self.order_type)
    else
      raise "Order type must be either forward or reverse."
    end
  end

  def validate_quantity
    if self.quantity.to_f <= 0
      raise "Quantity cannot be less or equal to 0"
    end
  end

  def create_invoice(items, order_type)
    invoice_no = OrderManagementItem.get_invoice_no(order_type)
    invoice_data = {invoice_no: invoice_no, invoice_creation_date: Date.current}
    items.each do |item|
      omi = self.order_management_items.find_by(id: item[:id])
      omi&.create_invoice(invoice_data.merge({quantity: item[:quantity].to_i}))
    end
    invoice_no
  end

  def self.get_print_data(order_management_system)
    {
    rrd_creation_date: order_management_system.rrd_creation_date,
    reason_reference_document_no: order_management_system.reason_reference_document_no,
    status: order_management_system.status,
    order_reason: order_management_system.order_reason,
    oms_type: order_management_system.oms_type,
    order_type: order_management_system.order_type,
    items: order_management_system.order_management_items.map { |item| {sku_code: item.sku_code, item_description: item.item_description, price: item.price, quantity: item.quantity, total_price: item.total_price, status: item.status }}
    }
  end
end
