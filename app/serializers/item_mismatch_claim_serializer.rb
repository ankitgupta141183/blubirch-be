class ItemMismatchClaimSerializer < ActiveModel::Serializer
  attributes :id, :tag_id, :article_id, :mrp, :tested_by, :received_mrp, :received_article_id, :debit_note_request_against, :debit_note_request_name, :debit_note_request_amount

  def tag_id
    object.tag_number
  end

  def article_id
    object.sku_code
  end

  def tested_by
    object.confirmed_by
  end

  def received_article_id
    object.received_sku
  end

  def debit_note_request
    object.details&.dig('item_mismatch_debit_note_request')
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
