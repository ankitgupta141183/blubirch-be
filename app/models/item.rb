# frozen_string_literal: true

# nodoc
# item class for inwarding
class Item < ApplicationRecord
  acts_as_paranoid
  # serialize :details, Hash

  default_scope { where(deleted_at: nil) }
  scope :without_claims, -> { where('current_status IS NULL OR current_status NOT IN (?)', ['No Claims', '3p Claims']) }
  scope :no_logistic_claim, -> { where.not("details ? 'logistic_debit_note_request' OR details ? 'logistic_no_claim'")}
  scope :no_item_mismatch_claim, -> { where.not("details ? 'item_mismatch_debit_note_request' OR details ? 'item_mismatch_no_claim'")}
  scope :no_grade_mismatch_claim, -> { where.not("details ? 'grade_mismatch_debit_note_request' OR details ? 'grade_mismatch_no_claim'")}
  scope :boxes, -> { where(parent_id: nil, tag_number: nil) }
  scope :exclude_boxes, -> { where.not(parent_id: nil, tag_number: nil) }

  belongs_to :user
  has_many :box_images, as: :attachmentable
  has_many :items, class_name: 'Item', foreign_key: 'parent_id'
  belongs_to :return_item, optional: true
  
  validates :tag_number, uniqueness: { allow_blank: true }
  validate  :supplier_details, :set_supplier_name, if: ->(object) { object.tag_number.present? }
  validates :asp, numericality: { greater_than: 0 }, if: ->(object) { object.tag_number.present? }
  before_validation :set_client_category_id
  before_create :set_received_mrp, :set_irrd_number
  before_save :update_changed_sku, :update_details, :create_inventory

  # CSV_HEADERS = ['tag_number', 'sku_code', 'reverse_dispatch_document_number', 'sku_description', 'serial_number_1', 'serial_number_2', 'location', 'sub_location', 'document_number', 'document_type', 'document_type_id', 'consignment_number', 'client_category_name', 'client_category_id', 'quantity',  'disposition', 'mrp', 'map', 'supplying_site_name', 'receiving_site_name', 'inwarding_disposition', 'client_tag_number', 'return_reason', 'return_grade', 'return_reamrks', 'logistics_partner_name', 'box_number', 'box_condition', 'is_sub_box', 'transporter_name', 'transporter_contact_number', 'transporter_vehicle_number', 'logistics_receipt_date', 'logistic_awb_number', 'is_serialized_item', 'brand', 'sales_invoice_date', 'installation_date', 'purchase_invoice_date', 'purchase_price', 'field_attributes', 'grade', 'asp', 'supplier', 'client_resolution', 'item_resolution' ]
  CSV_HEADERS = ['Tag Number', 'Article ID', 'Article Description', 'Brand', 'Reverse Dispatch Document Number', 'Serial Number 1', 'Serial Number 2', 'Document Number', 'Document Type',
                 'Client Category Name', 'MRP', 'MAP', 'Return Reason', 'Box Number', 'Box Condition', 'Sales Invoice Date', 'Installation Date', 'Purchase Invoice Date', 'Purchase Price',
                 'Field Attributes', 'Grade', 'ASP', 'Supplier', 'Client Resolution', 'Item Resolution', 'Category L1', 'Category L2', 'Category L3'].freeze
  # def self.import_inward_details_from_json_file(tmp_file, current_user, client_id)
  #   json_data = File.read(tmp_file)
  #   parsed_data = JSON.parse(json_data)
  #   payloads = parsed_data["payload"]
  #   payloads.each do |payload|
  #     items = payload["items"]
  #     items.each do |item|
  #       hash = create_hash(item)
  #       lookup_key = LookupKey.find_by(name: 'INWARD_STATUSES', code: 'INWARD_STATUSES')
  #       lookup_value = LookupValue.find_by(lookup_key_id: lookup_key&.id, code: 'inward_statuses_pending_receipt', original_code: 'Pending Receipt')
  #       hash.merge!({status: lookup_value&.original_code, status_id: lookup_value&.id, user_id: current_user.id, client_id: client_id, document_number: payload['document_number'], document_type: payload['document_type'], document_date: payload[:document_date]})
  #       item = Item.create(hash)
  #     end
  #   end
  # end

  def self.inwarded_boxes_with_pending_items
    joins('LEFT JOIN items AS associated_items ON items.id = associated_items.parent_id')
      .where(box_status: 'Box Inwarded')
      .where("associated_items.status = 'Pending Receipt' OR (associated_items.status = 'Inwarded' AND (associated_items.grn_number IS NULL OR associated_items.grade IS NULL))")
  end

  def self.import_inward_details_from_file(tmp_file, current_user, client_id)
    file = File.new(tmp_file)
    file_data = CSV.read(file.path, headers: true, encoding: 'iso-8859-1:utf-8')
    lookup_key = LookupKey.find_by(name: 'INWARD_STATUSES', code: 'INWARD_STATUSES')
    lookup_value = LookupValue.find_by(lookup_key_id: lookup_key&.id, code: 'inward_statuses_pending_receipt', original_code: 'Pending Receipt')
    pend_inward = LookupValue.find_by(lookup_key_id: lookup_key&.id, code: 'inward_statuses_pending_item_inwarding')
    # error_details = ['tag_number', 'sku_code', 'reverse_dispatch_document_number', 'errors']
    error_details = []
    client_id ||= Client.first.id
    begin
      items = Item.where("status = 'Pending Item Resolution' OR box_status = 'Pending Box Resolution'").where(client_id: client_id)
      file_data.each do |data|
        # data = data.to_h
        hash = generate_hash(data)
        box_number = hash[:box_number]
        user_id = current_user.id
        box = Item.find_by(box_number: box_number, parent_id: nil, box_status: 'Box Inwarded')
        if box.blank?
          hash.merge!({ details: { 'asp' => hash[:asp] }, changed_sku_code: nil, user_id: user_id, client_id: client_id, status: lookup_value&.original_code, status_id: lookup_value&.id })
          item = items.find_by(tag_number: hash[:tag_number], status: 'Pending Item Resolution', item_issue: 'Tag id Mismatch')
          if item.present?
            item.attributes = hash
            item.status = pend_inward.original_code
            item.status_id = pend_inward.id
            inward = item
          else
            box = items.find_by(box_number: box_number, tag_number: nil, box_status: 'Pending Box Resolution')
            if box.present?
              box.update(box_number: box_number, reverse_dispatch_document_number: hash[:reverse_dispatch_document_number], box_status: nil, box_status_id: nil,
                         box_condition: hash[:box_condition], location: hash[:location], client_id: client_id, tag_number: nil, user_id: user_id, supplier: hash[:supplier])
            else
              box = Item.find_or_create_by(box_number: box_number, reverse_dispatch_document_number: hash[:reverse_dispatch_document_number], supplier: hash[:supplier],
                                           box_condition: hash[:box_condition], location: hash[:location], client_id: client_id, tag_number: nil, user_id: user_id)
            end
            inward = Item.new(hash.merge!({ parent_id: box.id }))
          end
          inward_item_resolution = inward.item_resolution?
          unless inward_item_resolution && inward.save
            msg = inward_item_resolution ? inward.errors.full_messages.join(',') : 'PRD not created as item resolution false'
            error_details << { box_number: nil, tag_number: inward.tag_number, sku_code: inward.sku_code, reverse_dispatch_document_number: inward.reverse_dispatch_document_number, errors: msg }
          end
        else
          msg = 'PRD is not created as provided box number is already inwarded.'
          error_details << { box_number: box.box_number, tag_number: nil, sku_code: nil, reverse_dispatch_document_number: nil, errors: msg }
        end
      end
      [true, error_details]
    rescue StandardError => e
      e
      [false, e.message]
    end
  end

  def sku_code
    return super if Rails.application.credentials.is_client_decathlon.blank? || changed_sku_code.blank?

    changed_sku_code
  end

  def update_changed_sku
    rails_creds = Rails.application.credentials
    return if grade.blank? || rails_creds.is_client_decathlon.blank? || !grade_changed?

    # API for rule engine starts
    url =  "#{rails_creds.rule_engine_url}/api/v1/sku_grade_rules"
    response = RestClient::Request.execute(method: :get, url: url, payload: {}, verify_ssl: OpenSSL::SSL::VERIFY_NONE)
    # API for rule engine ends
    return if response.blank?

    parsed_res = JSON.parse(response)
    self.changed_sku_code = "#{self[:sku_code]}_#{grade}" if parsed_res.include?(grade)
  end

  def create_dispostions(disposition, third_party_claim_attrs = nil)
    return if client_resolution.blank?

    inventory = find_or_create_inventory
    inv_new_record = inventory.new_record?
    return unless inv_new_record || disposition.to_s == '3pClaim'

    inventory.disposition = disposition
    if inv_new_record && inventory.save && inventory.grade.present?
      details = inventory['details']
      user = User.find_by(username: details['inward_user_name'])
      InventoryGradingDetail.store_grade_inventory(inventory.id, details['final_grading_result'], details['processed_grading_result'], grade, user)
    end
    assign_dispotion(inventory, disposition, third_party_claim_attrs)
  end

  def assign_dispotion(inventory, disposition, third_party_claim_attrs)
    case disposition
    when 'Brand Call-Log'
      BrandCallLog.create_record(inventory, user_id)
    when 'Insurance'
      Insurance.create_record(inventory, user_id)
    when 'Replacement'
      Replacement.create_record(inventory, user_id)
    when 'Repair'
      Repair.create_record(inventory, user_id)
    when 'Liquidation'
      Liquidation.create_record(inventory, nil, user_id)
    when 'Redeploy'
      Redeploy.create_record(inventory, user_id)
    when 'Pending Transfer Out', 'Markdown'
      Markdown.create_record(inventory, user_id)
    when 'E-Waste'
      EWaste.create_record(inventory, user_id)
    when 'RTV'
      VendorReturn.create_rtv_record(inventory, user_id)
    when 'Pending Disposition'
      PendingDisposition.create_record(inventory, user_id)
    when 'Restock'
      Restock.create_record(inventory, user_id)
    when '3pClaim'
      third_party_claim_attrs.merge!(inventory_id: inventory.id)
      ThirdPartyClaim.create_thrid_party_claim([third_party_claim_attrs])
    end
  end

  def find_or_create_inventory
    inventory = Inventory.find_or_initialize_by(tag_number: tag_number)
    return inventory unless inventory.new_record?

    inventory.assign_attributes(distribution_center_id: distribution_center_id, client_id: client_id, user_id: user_id, details: details, sku_code: self[:sku_code], item_description: sku_description,
                                item_price: mrp, client_category_id: client_category_id, quantity: quantity, grade: grade, serial_number: serial_number_1, return_reason: return_reason, sr_number: serial_number_1,
                                serial_number_2: serial_number_2, status: status, status_id: status_id, is_putaway_inwarded: false, is_forward: false)
    inventory
  end

  def distribution_center_id
    DistributionCenter.find_by(name: location)&.id || DistributionCenter.first.id
  end

  def update_details
    grn_time = grn_submitted_time.to_s
    self.details = {} if details.nil?
    hash = { 'rdd_number' => reverse_dispatch_document_number, 'ean' => ean, 'brand' => brand, 'grn_number' => grn_number, 'stn_number' => serial_number_1, 'inward_user_id' => user_id,
             'destination_code' => location, 'grn_received_time' => grn_time, 'grn_submitted_date' => grn_time, 'client_sku_master_id' => self[:sku_code],
             'grn_received_user_id' => user_id, 'grn_submitted_user_id' => user_id, 'inwarding_disposition' => disposition, 'changed_sku_code' => changed_sku_code,
             'category_l1' => category_node&.dig('Category L1'), 'category_l2' => category_node&.dig('Category L2'), 'category_l3' => category_node&.dig('Category L3'),
             'sales_invoice_date' => sales_invoice_date.to_s, 'installation_date' => installation_date.to_s, 'purchase_invoice_date' => purchase_invoice_date.to_s,
             'purchase_price' => purchase_price, 'supplier' => supplier, 'item_inwarded_date' => item_inwarded_date.to_s }
    details.merge!(hash)
    inv = Inventory.find_by(tag_number: tag_number)
    inv.update(details: details) if inv.present?
  end

  def create_inventory
    inv = Inventory.find_by(tag_number: tag_number)
    return if client_resolution.blank? || inv.present? || grade.blank?
    # Setting dispostion inside the field when fetch the grade, so  no need to fetch again
    # url =  "#{Rails.application.credentials.rule_engine_url}/api/v1/dispositions"
    # answers = [{ 'test_type' => 'Grade', 'output' => grade }, { 'test_type' => 'Own Label', 'output' => 'Own Label' },
    #            { 'test_type' => 'Return Reason', 'output' => return_reason }]
    # serializable_resource = { client_name: 'croma', answers: answers }.as_json
    # response = RestClient::Request.execute(method: :post, url: url, payload: serializable_resource, verify_ssl: OpenSSL::SSL::VERIFY_NONE)
    create_dispostions(disposition)
  end

  def self.create_hash(data)
    details_hash = data.except('tag_number', 'article', 'article_description', 'item_attributes', 'serial_number1', 'serial_number2', 'mrp', 'map', 'return_subrequest_reason', 'box_number', 'ean',
                               'model', 'category_code', 'category_node', 'sales_price', 'purchase_price', 'brand', 'article_name', 'purchase_invoice_date', 'installation_date',
                               'sales_invoice_date', 'grade')
    { details: details_hash, prd_grade: data['grade'], tag_number: data['tag_number'], sku_code: data['article'], sku_description: data['article_description'],
      field_attributes: data['item_attributes'], serial_number_1: data['serial_number1'], serial_number_2: data['serial_number2'], mrp: data['mrp'], map: data['map'],
      return_reason: data['return_subrequest_reason'], box_number: data['box_number'], ean: data['ean'], model: data['model'], category_node: data['category_node'].to_h,
      category_code: data['category_code'], sales_price: data['sales_price'], purchase_price: data['purchase_price'], brand: data['brand'], client_category_name: data['article_name'],
      sales_invoice_date: data['sales_invoice_date'], installation_date: data['installation_date'], purchase_invoice_date: data['purchase_invoice_date'] }
  end

  def set_client_category_id
    return if client_category_id.present? || tag_number.blank?

    self.client_category_id = ClientCategory.where(name: client_category_name).first&.id
    if client_category_id.blank?
      errors.add(:client_category_id, "Can't be blank.")
    end
  end

  def supplier_details
    suppliers = supplier.to_s.downcase
    vedor_master = VendorMaster.where('lower(vendor_name) = ? OR lower(vendor_code) = ?', suppliers, suppliers).first
    errors.add(:supplier, 'is not present.') if vedor_master.blank?
  end

  def set_supplier_name
    return if tag_number.blank?

    suppliers = supplier.to_s.downcase
    vedor_master = VendorMaster.where('lower(vendor_name) = ? OR lower(vendor_code) = ?', suppliers, suppliers).first
    self.supplier = vedor_master.vendor_name
    details['supplier'] = supplier
    details['vendor_code'] = vedor_master.vendor_code
  end

  def self.generate_hash(data)
    field_attributes = YAML.safe_load(data['Field Attributes'])
    category_node = { 'Category L1' => data['Category L1'], 'Category L2' => data['Category L2'], 'Category L3' => data['Category L3'] }
    {
      tag_number: data['Tag Number'], sku_code: data['Article ID'], sku_description: data['Article Description'], brand: data['Brand'], box_number: data['Box Number'],
      box_condition: data['Box Condition'], reverse_dispatch_document_number: data['Reverse Dispatch Document Number'], serial_number_1: data['Serial Number 1'],
      serial_number_2: data['Serial Number 2'], document_number: data['Document Number'], document_type: data['Document Type'], client_category_name: data['Client Category Name'], mrp: data['MRP'],
      map: data['MAP'], return_reason: data['Return Reason'], sales_invoice_date: data['Sales Invoice Date'], installation_date: data['Installation Date'],
      purchase_invoice_date: data['Purchase Invoice Date'], purchase_price: data['Purchase Price'], field_attributes: field_attributes, prd_grade: data['Grade'],
      asp: data['ASP'], supplier: data['Supplier'], client_resolution: data['Client Resolution'].to_s.downcase == 'yes', item_resolution: data['Item Resolution'].to_s.downcase == 'yes',
      category_node: category_node
    }
  end

  def set_received_mrp
    return if parent_id.blank? || tag_number.blank?

    self.received_mrp = ClientSkuMaster.find_by(code: sku_code)&.mrp
  end
  
  def set_irrd_number
    return if irrd_number.present?
    
    self.irrd_number = ReturnItem.generate_irrd
    self.ird_number = ReturnItem.generate_ird
    self.return_sub_request_id = ReturnItem.generate_return_sub_request_number
  end
  
  # Inwarding from Return Initiation
  def self.inward_return_items(return_items, client_id)
    client_id ||= Client.first.id
    user_id = Current.user.id
    pending_items = Item.where("status = 'Pending Item Resolution' OR box_status = 'Pending Box Resolution'").where(client_id: client_id)
    
    lookup_key = LookupKey.find_by(code: 'INWARD_STATUSES')
    pending_receipt_status = lookup_key.lookup_values.find_by(code: 'inward_statuses_pending_receipt')
    pending_inward_status = lookup_key.lookup_values.find_by(code: 'inward_statuses_pending_item_inwarding')
    
    begin
      return_items.each do |return_item|
        category_details = return_item.client_sku_master&.description
        category_node = { 'Category L1' => category_details&.dig("category_l1"), 'Category L2' => category_details&.dig("category_l2"), 'Category L3' => category_details&.dig("category_l3") }
        hash = {
          tag_number: return_item.tag_number, sku_code: return_item.sku_code, sku_description: return_item.sku_description, box_number: return_item.box_number, serial_number_1: return_item.serial_number,
          reverse_dispatch_document_number: return_item.irrd_number, document_number: return_item.ird_number, return_reason: return_item.return_reason, quantity: return_item.quantity, changed_sku_code: nil,
          user_id: user_id, client_id: client_id, return_item_id: return_item.id, location: return_item.delivery_location&.name, asp: return_item.asp, mrp: return_item.mrp, map: return_item.map,
          purchase_price: return_item.item_amount, brand: return_item.brand, category_node: category_node, client_category_name: return_item.category_name, details: { 'asp' => return_item.asp },
          status: pending_receipt_status&.original_code, status_id: pending_receipt_status&.id, client_resolution: true, item_resolution: true, supplier: VendorMaster.last.vendor_name,              # TODO: update supplier
          irrd_number: return_item.irrd_number, ird_number: return_item.ird_number, return_sub_request_id: return_item.return_sub_request_id
        }
        
        box_number = return_item.box_number
        box = pending_items.find_by(box_number: box_number, tag_number: nil, box_status: 'Pending Box Resolution')
        if box.present?
          box.update(reverse_dispatch_document_number: hash[:reverse_dispatch_document_number], box_status: nil, box_status_id: nil,
                     location: hash[:location], client_id: client_id, user_id: user_id, supplier: hash[:supplier], box_condition: hash[:box_condition])
        else
          box = Item.find_or_create_by(box_number: box_number, reverse_dispatch_document_number: hash[:reverse_dispatch_document_number], supplier: hash[:supplier],
                                       box_condition: hash[:box_condition], location: hash[:location], client_id: client_id, tag_number: nil, user_id: user_id)
        end
        item = Item.new(hash.merge!({ parent_id: box.id }))
        item.save!
      end
      [true, {}]
    rescue StandardError => e
      [false, e.message]
    end
  end
  
  def get_inward_status
    if (status == 'Inwarded' && grade.present? && disposition.present?)
      "Closed"
    else
      "Open"
    end
  end
end
