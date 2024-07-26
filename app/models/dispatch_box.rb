class DispatchBox < ApplicationRecord
  has_many :warehouse_order_items
  
  validates_presence_of :box_number
  
  mount_uploader :handover_document, ConsignmentFileUploader
  
  enum status: { pending: 1, dispatched: 2 }, _prefix: true
  enum mode: { dispatch: 1, handover: 2 }, _prefix: true
  enum logistic_partner: { blue_dart: 1, dhl: 2 }, _prefix: true
  
  OUTWARD_REF_DOCUMENTS = { 1 => "Sales Invoice", 2 => "DC", 3 => "Returnable DC", 4 => "Replacement DC", 5 => "Stock Transfer Note" }
  OUTWARD_REASON_REF_DOCUMENT = {"LiquidationOrder" => "Sales Invoice", "VendorReturnOrder" => "DC", "RepairOrder" => "Returnable DC", "ReplacementOrder" => "Replacement DC", "MarkdownOrder" => "Stock Transfer Note", "TransferOrder" => "Stock Transfer Note" }
  
  scope :filter_by_box_number, -> (box_number) { where("box_number like ?", "%#{box_number}%") }
  scope :filter_by_destination_type, -> (destination_type) { where("destination_type like ?", "%#{destination_type}%") }
  
  def tag_numbers
    self.warehouse_order_items.pluck(:tag_number)
  end
  
  def or_document
    orderable_type = self.warehouse_order_items.first.try(:warehouse_order).try(:orderable_type)
    or_document = OUTWARD_REASON_REF_DOCUMENT[orderable_type] || "Stock Transfer Note"
    OUTWARD_REF_DOCUMENTS.invert[or_document]
  end
  
  def update_dispatch_details(params)
    dispatch_box = self
    dispatch_box.assign_attributes(outward_reference_value: params[:outward_reference_value].to_a, vehicle_number: params[:vehicle_number],
      dispatch_document_number: params[:dispatch_document_number], handover_document: params[:handover_document]
    )
    dispatch_box.outward_reference_document = params[:outward_reference_document].to_i if params[:outward_reference_document].present?
    dispatch_box.logistic_partner = params[:logistic_partner].to_i if params[:logistic_partner].present?
    dispatch_box.mode = params[:mode].to_i if params[:mode].present?
    dispatch_box.status = :dispatched
    dispatch_box.save!
    
    
    # cancelled items will move to 'Pending Disposition' state
    warehouse_order_item_ids = dispatch_box.warehouse_order_items.pluck(:id)
    if params[:cancelled_items].present?
      params[:cancelled_items].each do |row|
        cancelled_items = dispatch_box.warehouse_order_items.where(tag_number: row["tag_ids"])
        cancelled_items.each do |cancel_item|
          warehouse_order_item_ids = warehouse_order_item_ids - [cancel_item.id]
          cancel_item.tab_status = :pending_disposition
          cancel_item.reject_reason = row["reject_reason"].to_i
          cancel_item.save!
          
          bucket_status = LookupValue.where(code: "dispatch_status_pending_disposition").last
          cancel_item.inventory.update_inventory_status!(bucket_status, Current.user&.id)
        end
      end
    end

    dispatch_box.warehouse_order_items.where(id: warehouse_order_item_ids).each do |order_item|


      bucket_status = LookupValue.where(code: "dispatch_status_dispatched").last
      order_item.update!(ord: params[:outward_reference_value].to_a.join(','), tab_status: :dispatched, status_id: bucket_status.id, status: bucket_status.original_code)
      order_item.inventory.update!(status_id: bucket_status.id, status: bucket_status.original_code)
      order_item.inventory.update_inventory_status!(bucket_status, Current.user&.id)
  
      if order_item.warehouse_order.orderable_type == "RepairOrder"
        order_item.warehouse_order.orderable.repairs.each do |repair|
          repair.repair_status = :pending_receipt_from_service_center
          repair.save!
        end
      end
      if order_item.warehouse_order.orderable_type == "ReplacementOrder"
        if (order_item.warehouse_order.outward_invoice_number == nil)
          outward_reference_value = params[:outward_reference_value].to_a.join(', ')
          order_item.warehouse_order.outward_invoice_number = outward_reference_value
          order_item.warehouse_order.save
        end
        replacements = order_item.warehouse_order.orderable.replacements
        next_status = LookupValue.find_by(code: "replacement_status_pending_replacement").original_code
        next_status_id = LookupValue.find_by(original_code: next_status).try(:id)
        replacements.update_all(status: next_status, status_id: next_status_id)
      end
    end
  end
  
  FILE_FORMATS = %w(.jpg .jpeg .png .pdf)
  def self.validate_dispatch_details(params)
    if params[:handover_document].present?
      ext = File.extname(params[:handover_document].original_filename)
      raise CustomErrors.new "Invalid file format" unless FILE_FORMATS.include? ext
    end
    
    destinations = self.pluck(:destination).uniq
    raise CustomErrors.new "Destination should be same for the selected boxes." if (destinations.count > 1)
    
    selected_items = WarehouseOrderItem.where(dispatch_box_id: self.pluck(:id))
    warehouse_order = selected_items.first.warehouse_order
    all_lot_items = warehouse_order.warehouse_order_items.where(tab_status: [1,2,3])
    raise CustomErrors.new "Can not be dispatched. All the items from this lot #{warehouse_order.reference_number} must be dispatched at once." if (all_lot_items.count > selected_items.count)
    
    # params[:cancelled_items] = [{"reject_reason"=>1, "tag_ids"=>["2f2880", "aa3b41", "681c06"]}, {"reject_reason"=>1, "tag_ids"=>["2f2880", "aa3b41", "681c06"]}]
    if params[:cancelled_items].present?
      tag_numbers = params[:cancelled_items].map{|row| row["tag_ids"] }.flatten.uniq
      cancelled_items = selected_items.where(tag_number: tag_numbers)
      raise CustomErrors.new "Invalid Cancelled Tag ID." if (tag_numbers.count > cancelled_items.count)
    end
  end
end
