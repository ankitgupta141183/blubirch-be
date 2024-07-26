# frozen_string_literal: true

class PrdSerializer < ActiveModel::Serializer
  include Utils::Formatting

  attributes :id, :prd_number, :irrd_number, :irrd_type, :irrd_date, :ird_number, :ird_type, :ird_date, :tag_number, :sku_code, :sku_description, :quantity, :serial_number1, :serial_number2, :created_date, :vendor_name, :purchase_price
  
  # delegate :return_item, to: :object

  def prd
    object.pending_receipt_document
  end
  
  def irrd_number
    prd.inward_reason_reference_document_number
  end
  
  def irrd_type
    prd.inward_reason_reference_document_type
  end
  
  def irrd_date
    format_date(prd.inward_reason_reference_document_date)
  end
  
  def ird_number
    prd.inward_reference_document_number
  end
  
  def ird_type
    prd.inward_reference_document_type
  end
  
  def ird_date
    format_date(prd.inward_reference_document_date)
  end

  def created_date
    format_date(object.created_at.to_date)
  end
  
  def vendor_name
    object.vendor&.vendor_name
  end
  
  def purchase_price
    object.purchase_price.to_f
  end

end
