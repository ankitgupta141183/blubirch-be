class Consignment < ApplicationRecord
  acts_as_paranoid
  belongs_to :distribution_center, optional: true
  belongs_to :logistics_partner
  belongs_to :user
  has_many :consignment_informations
  has_many :consignment_boxes, class_name: "ConsignmentBoxImage"
  has_many :consignment_gate_passes
  has_many :consignment_files
  accepts_nested_attributes_for :consignment_files

  mount_uploader :consignment_receipt, ConsignmentFileUploader
  mount_uploader :acknowledgement_receipt, ConsignmentFileUploader
  mount_uploaders :damage_certificates, ConsignmentFileUploader

  # TODO: uncomment later
  # validates_presence_of :consignment_id

  enum status: { initiated: 1, submitted: 2 }, _prefix: true

  def generate_receipt
    data = []
    consignment_informations.each do |consignment_info|
      consignment_info_data = consignment_info.as_json(only: %i[id dispatch_document_number boxes_count])
      consignment_info_data[:box_numbers] = consignment_info.consignment_boxes.pluck(:box_number).compact
      data << consignment_info_data
    end

    # generating pdf
    pdf = ConsignmentPdf.new(get_pdf_data)
    pdf.render_file(Rails.root.join('public', "consignment-receipt.pdf"))

    pdf_file = File.open('public/consignment-receipt.pdf')
    file_name = "consignment-receipt-#{consignment_id}.pdf"

    amazon_s3 = Aws::S3::Resource.new(region: Rails.application.credentials.aws_s3_region, access_key_id: Rails.application.credentials.access_key_id, secret_access_key: Rails.application.credentials.secret_access_key)
    bucket = Rails.application.credentials.aws_bucket

    obj = amazon_s3.bucket(bucket).object("uploads/consignment/consignment_receipt/#{id}/#{file_name}")

    obj.put(body: pdf_file, acl: 'public-read', content_type: 'application/pdf')

    receipt_url = obj.public_url
    # deleting the tmp file
    # File.delete('public/consignment-receipt.pdf')
		
    return_data = {id: id, consignment_id: consignment_id, dispatch_documents: data, receipt_url: receipt_url}
  end

  def get_pdf_data
    pdf_data = {}
    pdf_data[:consignment_details] = [['Consignment ID(Gate Pass)', consignment_id], ['Location', distribution_center.code], ['Logistics Partner', logistics_partner.name], ['Receipt Date', format_date(Date.current)]]
		
    box_numbers = consignment_boxes.pluck(:box_number).compact
    if box_numbers.present?
      pdf_data[:dispatch_documents] = [['DDN', 'Number of boxes in DDN', 'Boxes Received', 'Received Damaged']]
      consignment_informations.each do |consignment_info|
        pdf_data[:dispatch_documents] << [consignment_info.dispatch_document_number, consignment_info.boxes_count, (consignment_info.good_boxes_count.to_i + consignment_info.damaged_boxes_count.to_i), consignment_info.damaged_boxes_count]
      end
			
      damaged_boxes = consignment_boxes.where(is_damaged: true)
      if damaged_boxes.present?
        pdf_data[:damaged_boxes] = [['Box ID', 'Number of items']]
        damaged_boxes.each do |box|
          pdf_data[:damaged_boxes] << [box.box_number, box.damaged_box_items.to_i]
        end
      end
			
    else
      pdf_data[:dispatch_documents] = [['DDN', 'Number of boxes in DDN', 'Boxes Received', 'Received Damaged', 'Number of items in damaged boxes']]
      consignment_informations.each do |consignment_info|
        total_damaged_items = consignment_info.consignment_boxes.sum(:damaged_box_items)
        pdf_data[:dispatch_documents] << [consignment_info.dispatch_document_number, consignment_info.boxes_count, (consignment_info.good_boxes_count.to_i + consignment_info.damaged_boxes_count.to_i), consignment_info.damaged_boxes_count, total_damaged_items]
      end
    end
		
    pdf_data
  end
end