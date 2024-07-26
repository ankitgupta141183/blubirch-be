class Api::V2::Warehouse::MarkdownWarehouseOrderItemSerializer < ActiveModel::Serializer
  attributes :id, :article_id, :article_description, :price, :grade, :category, :tag_id, :asp, :markdown_price, :markdown_location, :challan, :warehouse_order_status, :transfer_order_no

  def tag_id
    object.tag_number rescue 'NA'
  end

  def article_id
    object.sku_master_code || "NA"
  end 

  def article_description
    object.item_description || 'NA'
  end

  def price
    object.inventory.markdown.asp rescue 'NA'
  end

  def grade
    object.inventory.markdown.grade rescue 'NA'
  end

  def category
    object.client_category_name rescue nil
  end

  def asp
    object.inventory.markdown.asp.round(2) rescue nil
  end

  def markdown_price
    object.inventory.markdown.details['markdown_price'].round(2) rescue nil
  end

  def markdown_location
    object.inventory.markdown.distribution_center.code rescue nil
  end

  def warehouse_order_status
    object.tab_status_to_status[object.tab_status.to_sym]  rescue ''
  end

  def challan
    object.warehouse_order.delivery_reference_number rescue '-'
  end

  def transfer_order_no
    object.warehouse_order.orderable.order_number
  end
end
