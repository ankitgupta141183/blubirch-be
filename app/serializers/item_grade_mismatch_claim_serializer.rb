class ItemGradeMismatchClaimSerializer < ActiveModel::Serializer
  attributes :id, :tag_id, :article_id, :mrp, :prd_grade, :grade, :tested_by, :debit_note_request_against, :debit_note_request_name, :debit_note_request_amount

  def tag_id
    object.tag_number
  end

  def article_id
    object.sku_code
  end

  def debit_note_request
    object.details&.dig('grade_mismatch_debit_note_request')
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


  # def tested_by
  #   object.details.dig('inward_user_name') rescue nil
  # end
end
