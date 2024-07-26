class DealerOrderSerializer < ActiveModel::Serializer
  has_many :dealer_order_items
  
  attributes :id, :dealer_code, :dealer_name, :dealer_city, :dealer_state, :dealer_country, :dealer_pincode, :client_id, :dealer_id, :dealer_phone_number, :dealer_email, :quantity, :total_amount, :discount_percentage, :discount_amount, :order_amount, :order_number, :status_id, :status, :approved_quantity, :rejected_quantity, :approved_amount, :rejected_amount, :approved_discount_percentage, :approved_discount_amount, :remarks, :user_id, :invoice_number, :invoice_attachement_file_type, :invoice_attachement_file, :invoice_user_id, :box_count, :received_box_count, :not_received_box_count, :excess_box_count, :sent_inventory_count, :received_inventory_count, :excess_inventory_count, :not_received_inventory_count, :dispatch_count, :tax_percentage, :tax_amount, :deleted_at, :created_at, :updated_at
  
end
