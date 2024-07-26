class ReturnInventoryInformationSerializer < ActiveModel::Serializer

  attributes :id, :reference_document, :reference_document_number, :sku_code, :sku_description, :serial_number, :quantity, :order_date,
             :item_value, :total_amount, :customer_name, :customer_email, :customer_phone, :customer_address_line1, :customer_address_line2, 
             :customer_address_line3, :customer_city, :customer_state, :customer_country, :customer_pincode, :status, :status_id, :user_id, :deleted_at

  belongs_to :user
  
end