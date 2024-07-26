class ConsignmentInformation < ApplicationRecord
  acts_as_paranoid
  belongs_to :consignment
  belongs_to :distribution_center
  has_many :consignment_attachments
  has_many :consignment_boxes, class_name: "ConsignmentBoxImage"
  
  validates_presence_of :dispatch_document_number
  
  enum status: { consignment_inwarded: 1, auto_inwarded: 2 }, _prefix: true
  
  def self.create_consignment_info(consignment, dispatch_document)
    consignment_info = consignment.consignment_informations.new({
      distribution_center_id: consignment.distribution_center_id, logistics_partner_id: consignment.logistics_partner_id,
      dispatch_document_number: dispatch_document[:dispatch_document_number], boxes_count: dispatch_document[:total_boxes_received], 
      good_boxes_count: dispatch_document[:good_boxes_count], damaged_boxes_count: dispatch_document[:damaged_boxes_count], status: :consignment_inwarded
    })
    consignment_info.user_id = Current.user.id
    consignment_info.save!
    
    # consignment attachments
    consignment_info.consignment_attachments.create(attachment_file: dispatch_document[:dispatch_document_attachment], attachment_type: 'Dispatch Document') if dispatch_document[:dispatch_document_attachment].present?
    
    if dispatch_document[:consignee_reference_documents].present?
      document_numbers = []
      dispatch_document[:consignee_reference_documents].each do |consignee_reference_document|
        consignment_info.consignment_attachments.create(attachment_file: consignee_reference_document[:attachment], attachment_type: 'Consignee Reference Document') if consignee_reference_document[:attachment].present?
        document_numbers << consignee_reference_document[:document_number]
      end
      consignment_info.consignee_ref_document_number = document_numbers.join(", ")
    end
    
    if dispatch_document[:inward_reason_reference_documents].present?
      document_numbers = []
      dispatch_document[:inward_reason_reference_documents].each do |inward_reason_reference_document|
        consignment_info.consignment_attachments.create(attachment_file: inward_reason_reference_document[:attachment], attachment_type: 'Inward Reason Reference Document') if inward_reason_reference_document[:attachment].present?
        document_numbers << inward_reason_reference_document[:document_number]
      end
      consignment_info.irrd_number = document_numbers.join(", ")
    end
    
    if dispatch_document[:vendor_reference_documents].present?
      document_numbers = []
      dispatch_document[:vendor_reference_documents].each do |vendor_reference_document|
        consignment_info.consignment_attachments.create(attachment_file: vendor_reference_document[:attachment], attachment_type: 'Vendor Reference Document') if vendor_reference_document[:attachment].present?
        document_numbers << vendor_reference_document[:document_number]
      end
      consignment_info.vendor_ref_number = document_numbers.join(", ")
    end
    
    # consignment box images
    if dispatch_document[:box_info].present?
      dispatch_document[:box_info].each do |box|
        consignment_box = consignment_info.consignment_boxes.new(consignment_id: consignment.id, box_number: box[:box_number], is_damaged: box[:is_damaged], damaged_box_items: box[:damaged_box_items_count])
        consignment_box.damaged_images = box[:damaged_box_images] if box[:damaged_box_images].present?
        consignment_box.save
      end
      consignment_info.good_boxes_count = consignment_info.consignment_boxes.where(is_damaged: false).count
      consignment_info.damaged_boxes_count = consignment_info.consignment_boxes.where(is_damaged: true).count
    else
      consignment_box = consignment_info.consignment_boxes.new(consignment_id: consignment.id, damaged_box_items: dispatch_document[:damaged_box_items_count])
      consignment_box.damaged_images = dispatch_document[:damaged_box_images] if dispatch_document[:damaged_box_images].present?
      consignment_box.save
    end
    
    consignment_info.save!
    consignment_info
  end
  
end
