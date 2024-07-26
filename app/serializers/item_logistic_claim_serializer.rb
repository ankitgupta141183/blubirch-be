class ItemLogisticClaimSerializer < ActiveModel::Serializer
  attributes :id, :tag_id, :reverse_dispatch_document_number, :logistics_partner_name, :receipt_date, :receipt_file, :debit_note_request_against, :debit_note_request_name, :debit_note_request_amount, :document_value, :damage_certificate

  def tag_id
    object.tag_number
  end

  def receipt_date
    object.box_inwarded_date.to_date.strftime("%d/%m/%Y")
  end
  
  def receipt_file
    box_receipt_file&.attachment_file&.url
  end
  
  def document_value
    ''
  end

  def damage_certificate
    find_damage_certificate&.attachment_file_url
  end

  def box_receipt_file
    @box_receipt_file ||= BoxReceiptAcknowledgement.find_by(reverse_dispatch_document_number: object.reverse_dispatch_document_number)
  end

  def find_damage_certificate
    @damage_certificate ||= DamageCertificate.find_by(reverse_dispatch_document_number: object.reverse_dispatch_document_number)
  end

  def debit_note_request
    object.details&.dig('logistic_debit_note_request')
  end

  def debit_note_request_against
    debit_note_request&.dig('raise_against')
  end

  def debit_note_request_name
    debit_note_request&.dig('name')
  end

  def debit_note_request_amount
    debit_note_request&.dig('amount')
  end
end
