class Api::V2::Warehouse::VendorReturnSerializer < ActiveModel::Serializer
  attributes :id, :inventory_id, :tag_number, :sku_code, :item_description, :brand, :vendor, :item_price, :approval_code, :confirmation_status, :date_for_dispatch, :return_document_type, :return_method

  def brand
    object.details['brand']
  end

  def vendor
    object.details&.dig('bcl_supplier') || 'N/A'
  end

  def approval_code
    object.details&.dig('bcl_approval_code') || 'N/A'
  end

  def confirmation_status
    object.details&.dig('return_date').present? ? 'Confirmed' : 'Not confirmed'
  end

  def date_for_dispatch
    object.details&.dig('return_date').to_date.strftime("%d-%m-%Y") rescue nil
  end

  def return_document_type
    object.details&.dig('return_document_type')
  end

  def return_method
    object.details&.dig('return_method')
  end
end
