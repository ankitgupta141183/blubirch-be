class ItemReturnRequestClaimSerializer < ActiveModel::Serializer
  attributes :id, :tag_id, :article_id, :article_description, :grade

  def tag_id
    object.tag_number
  end

  def article_description
    object.sku_description
  end

  def article_id
    object.sku_code
  end
end
