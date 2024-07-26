class DealerOrder < ApplicationRecord
  acts_as_paranoid
  has_many :dealer_order_items
  mount_uploader :invoice_attachement_file,  FileUploader
  enum tax_percentage_values: { gst: 18 }

  def self.generate_order_number
    loop do
      @order_number = "ORD-"+SecureRandom.hex(3)
      break @order_number unless DealerOrder.exists?(order_number: @order_number)
    end
  end

  def assign_status
    pending_approval_status = LookupValue.where(code: Rails.application.credentials.dealer_order_sts_pending_approval).last
    self.status_id = pending_approval_status.try(:id)
    self.status = pending_approval_status.try(:original_code)
  end

  def assign_dealer_details current_user_id
    dealer = User.find(current_user_id).dealers.last
    self.user_id = current_user_id
    self.dealer_id = dealer.try(:id)
    self.dealer_code = dealer.try(:dealer_code)
    self.dealer_name = dealer.try(:first_name)
    self.dealer_city = dealer.try(:city)
    self.dealer_state = dealer.try(:state)
    self.dealer_country = dealer.try(:country)
    self.dealer_pincode = dealer.try(:pincode)
    self.dealer_phone_number = dealer.try(:phone_number)
    self.dealer_email = dealer.try(:email)
  end

  def update_order_amounts
    self.quantity = self.dealer_order_items.sum(:quantity)
    self.order_amount = self.dealer_order_items.sum(:unit_price)
    self.discount_percentage = self.dealer_order_items.sum(:discount_percentage)
    self.discount_amount = self.dealer_order_items.sum(:discount_price)
    self.tax_percentage = DealerOrder.tax_percentage_values[:gst]
    self.tax_amount = ((self.order_amount-self.discount_amount)*self.tax_percentage)/100.to_f
    self.total_amount = (self.order_amount-self.discount_amount)+self.tax_amount
    self.save
  end

end
