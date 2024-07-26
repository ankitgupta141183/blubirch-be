class Api::V1::Warehouse::ReplacementWarehouseOrderItemSerializer < ActiveModel::Serializer
  attributes :id, :article_id, :article_description, :grade, :sku_master_code, :item_description, :tag_number, :status, :order_number, :price, :replacement_dc_number, :vendor, :approval_code_text, :return_method, :return_date, :brand, :tab_status, :ord

  def replacement_ord
    object.warehouse_order.orderable
  end

  def brand
    object.details['brand']
  end

  def article_id
    (object.inventory.sku_code rescue 'NA')
  end

  def article_description
    (object.inventory.item_description rescue 'NA')
  end

  def order_number
    object.warehouse_order.orderable.order_number
  end

  def price
    (object.inventory.item_price rescue 0)
  end

  def status
    object.tab_status_to_status[object.tab_status.to_sym]  rescue ''
  end

  def grade
    (object.inventory.grade rescue 'NA')
  end

  def replacement_dc_number
    (object.ord rescue '')
  end

  def vendor
    (object.warehouse_order.vendor_name rescue '')
  end

  def approval_code_text
    replacement_ord.replacements.first&.approval_code
  end
  
  def return_method
    replacement_ord.replacements.first&.return_method&.humanize
  end

  def return_date
    replacement_ord.replacements.first&.return_date
  end

end
