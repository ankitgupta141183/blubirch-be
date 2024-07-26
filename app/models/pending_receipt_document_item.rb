class PendingReceiptDocumentItem < ApplicationRecord
  acts_as_paranoid
  belongs_to :client
  belongs_to :distribution_center
  belongs_to :pending_receipt_document
  belongs_to :client_category, optional: true
  belongs_to :client_sku_master, optional: true
  belongs_to :vendor, class_name: 'VendorMaster', optional: true
  belongs_to :receiving_site_location, class_name: 'DistributionCenter', foreign_key: "receiving_site_id", optional: true
  has_one :inventory, dependent: :destroy
  has_one :forward_inventory, dependent: :destroy
  
  validates :tag_number, uniqueness: { allow_blank: true }
  
  after_create :generate_prd_number
  
  def generate_prd_number
    num = "P1" + "%04d" % self.id
    self.prd_number = num
    self.save!
  end
  
  def inward_item
    if disposition == 'Saleable'
      create_forward_inv
    else
      create_inv
    end
  end
  
  # Reverse
  def create_inv
    pending_grn_status = LookupValue.find_by(code: 'inward_statuses_pending_grn')
    
    tag_num = tag_number.present? ? tag_number : get_tag_number
    inventory = Inventory.new(tag_number: tag_num)
    # return inventory unless inventory.new_record?
    inventory.assign_attributes(distribution_center_id: distribution_center_id, client_id: client_id, user_id: user_id, sku_code: sku_code, item_description: sku_description,
                                item_price: mrp, client_category_id: client_category_id, quantity: quantity, grade: grade, serial_number: serial_number1, sr_number: serial_number1,
                                serial_number_2: serial_number2, status: pending_grn_status.original_code, status_id: pending_grn_status.id, is_putaway_inwarded: false, return_reason: return_reason)
    inventory.details = generate_details
    inventory.pending_receipt_document_item_id = id
    inventory.save!
    inventory
  end
  
  # Forward
  def create_forward_inv
    pending_grn_status = LookupValue.find_by(code: 'inward_statuses_pending_grn')
    prd = pending_receipt_document
    tag_num = tag_number.present? ? tag_number : get_tag_number
    
    forward_inv = ForwardInventory.new(tag_number: tag_num)
    forward_inv.assign_attributes(distribution_center_id: distribution_center_id, client_id: client_id, client_category_id: client_category_id, client_sku_master_id: client_sku_master_id,
                                vendor_id: vendor_id, inward_reason_reference_document: prd.inward_reason_reference_document_type, inward_reason_reference_document_number: prd.inward_reason_reference_document_number,
                                inward_reference_document: prd.inward_reference_document_type, inward_reference_document_number: prd.inward_reference_document_number,
                                sku_code: sku_code, item_description: sku_description, box_number: box_number, supplier: vendor&.vendor_name,
                                quantity: quantity, inwarded_quantity: quantity, grade: grade, brand: brand, serial_number: serial_number1, serial_number_2: serial_number2,
                                item_price: mrp, mrp: mrp, map: map, asp: asp, purchase_price: purchase_price, disposition: disposition,
                                status: pending_grn_status.original_code, status_id: pending_grn_status.id, return_reason: return_reason)
    forward_inv.details = generate_details
    forward_inv.pending_receipt_document_item_id = id
    forward_inv.save!
    forward_inv
  end
  
  def get_tag_number
    tag_num = Inventory.generate_tag
    all_invs = ForwardInventory.where(tag_number: tag_num)
    while all_invs.present?
      tag_num = Inventory.generate_tag
      all_invs = ForwardInventory.where(tag_number: tag_num)
    end
    tag_num
  end
  
  def generate_details
    details = { 'rdd_number' => pending_receipt_document.inward_reference_document_number, 'ean' => ean, 'brand' => brand, 'grn_number' => grn_number, 'stn_number' => '', 'inward_user_id' => user_id,
             'destination_code' => distribution_center.code, 'grn_received_time' => grn_submitted_date, 'grn_submitted_date' => grn_submitted_date,
             'client_sku_master_id' => client_sku_master_id, 'grn_received_user_id' => user_id, 'grn_submitted_user_id' => grn_submitted_user_id, 'inwarding_disposition' => disposition,
             'changed_sku_code' => '', 'category_l1' => category_details&.dig('category_l1'), 'category_l2' => category_details&.dig('category_l2'),
             'category_l3' => category_details&.dig('category_l3'), 'sales_invoice_date' => sales_invoice_date.to_s, 'installation_date' => installation_date.to_s,
             'purchase_invoice_date' => purchase_invoice_date.to_s, 'purchase_price' => purchase_price, 'supplier' => vendor&.vendor_name, 'vendor_code' => vendor&.vendor_code, 'item_inwarded_date' => created_at.to_date }
    details
  end
  
  def assign_dispotion
    if disposition == 'Saleable'
      DispositionRule.create_fwd_bucket_record(disposition, forward_inventory, nil, user_id)
    else
      DispositionRule.create_bucket_record(disposition, inventory, nil, user_id)
    end
  end
  
  def update_inventory
    if inventory.present?
      inventory.grade = grade
      inventory.details = generate_details
      inventory.save!
    elsif forward_inventory.present?
      forward_inventory.grade = grade
      forward_inventory.details = generate_details
      forward_inventory.save!
    else
      raise "Something went wrong! Item #{tag_number} not inwarded"
    end
  end
  
  def self.generate_csv(prd_items)
    prd_items = prd_items.includes(:pending_receipt_document)
    CSV.generate do |csv|
      csv << ['Sl. No.', 'PRD No.', 'Inward Reference Document Type', 'Inward Reference Document Number', 'Inward Reason Reference Document Type', 'Inward Reason Reference Document Number',
        'Consignee Reference Document Type', 'Consignee Reference Document Number', 'Vendor Reference Document Number', 'Inward Reference Document Date', 'Inward Reason Reference Document Date',
        'Supplying Site', 'Receiving Site', 'Supplying Organization', 'Receiving Organization', 'Box Number', 'Tag Number', 'SKU Code', 'SKU Description', 'Category Code', 'MRP', 'ASP', 'Sales Price', 'MAP', 'Purchase Price',
        'EAN', 'Brand', 'Model', 'Supplier', 'Quantity', 'Scan Indicator', 'Buyer Available', 'Grading Required', 'IMEI Flag', 'Serial Number 1', 'Serial Number 2', 'Test User', 'Test Date', 'Test Report Number',
        'Test Report URL', 'Grade', 'Return Request ID', 'Return Sub Request ID', 'Return Request Type', 'Return Request Sub Type', 'Return Reason', 'Return Request Date'
      ]

      prd_items.each_with_index do |prd_item, i|
        prd = prd_item.pending_receipt_document
        csv << [i + 1, prd_item.prd_number, prd.inward_reference_document_type, prd.inward_reference_document_number, prd.inward_reason_reference_document_type, prd.inward_reason_reference_document_number,
          prd.consignee_reference_document_type, prd.consignee_reference_document_number, prd.vendor_reference_document_number, format_date(prd.inward_reference_document_date),
          format_date(prd.inward_reason_reference_document_date), prd_item.supplying_site, prd_item.receiving_site, prd_item.supplier_organization, prd_item.receiving_organization, prd_item.box_number, prd_item.tag_number,
          prd_item.sku_code, prd_item.sku_description, prd_item.client_category&.name, prd_item.mrp.to_f, prd_item.asp.to_f, prd_item.sales_price.to_f, prd_item.map.to_f,
          prd_item.purchase_price.to_f, prd_item.ean, prd_item.brand, prd_item.model, prd_item.vendor&.vendor_code, prd_item.quantity.to_i, prd_item.scan_indicator, prd_item.buyer_available? ? 'Y' : 'N',
          prd_item.grading_required? ? 'Y' : 'N', prd_item.imei_flag, prd_item.serial_number1, prd_item.serial_number2, '', '', '', '', prd_item.grade, '', ''
        ]
      end
    end
  end
end
