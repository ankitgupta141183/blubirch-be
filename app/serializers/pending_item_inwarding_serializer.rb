class PendingItemInwardingSerializer < ActiveModel::Serializer

  attributes :id, :box_number, :tag_number, :reason, :artical_id

  def reason
    object.item_issue.to_s.downcase == 'tag id mismatch' ? 'Matching PRD' : 'Approved Item Mismatch'
  end

  def artical_id
    object.sku_code
  end
end
