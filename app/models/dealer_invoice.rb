class DealerInvoice < ApplicationRecord
  acts_as_paranoid
  has_many :dealer_invoice_items
  # enum tax_percentage_values: { central_tax_percentage: 18, state_tax_percentage: 10, inter_state_tax_percentage: 8 }

  def self.generate_invoice_number
    loop do
      @invoice_number = "INV-"+SecureRandom.hex(3)
      break @invoice_number unless DealerInvoice.exists?(invoice_number: @invoice_number)
    end
  end

  def assign_dealer_customer_details dealer_customer_id
    dealer_customer = DealerCustomer.find(dealer_customer_id)
    self.customer_code = dealer_customer.try(:code)
    self.customer_name = dealer_customer.try(:name)
    self.customer_phone_number = dealer_customer.try(:phone_number)
    self.customer_email = dealer_customer.try(:email)
    self.customer_gst = dealer_customer.try(:gst_number)
    # self.customer_city = dealer_customer.try(:city)
    # self.customer_state = dealer_customer.try(:state)
    # self.customer_country = dealer_customer.try(:country)
    # self.customer_pincode = dealer_customer.try(:pincode)
    # self.customer_company_name = dealer_customer.try(:city)
    # self.customer_address_1 = dealer_customer.try(:state)
    # self.customer_address_2 = dealer_customer.try(:country)
    self.save
  end

  def assign_dealer_details dealer_id
    dealer = Dealer.find(dealer_id)
    self.dealer_company_name = dealer.try(:company_name)
    self.dealer_address_1 = dealer.try(:address_1)
    self.dealer_address_2 = dealer.try(:address_2)
    self.dealer_city = dealer.try(:city)
    self.dealer_state = dealer.try(:state)
    self.dealer_country = dealer.try(:country)
    self.dealer_pincode = dealer.try(:pincode)
    self.dealer_gst = dealer.try(:gst_number)
    self.dealer_pan = dealer.try(:pan_number)
    self.dealer_cin = dealer.try(:cin_number)
  end

  def assign_payment payment_mode_id
    payment_type = LookupValue.find(payment_mode_id)
    self.payment_mode = payment_type.try(:original_code)
  end

  def update_order_amounts
    self.quantity = self.dealer_invoice_items.sum(:quantity)
    self.amount = self.dealer_invoice_items.sum(:unit_price)
    self.discount_percentage = self.dealer_invoice_items.sum(:discount_percentage)
    self.discount_amount = self.dealer_invoice_items.sum(:discount_price)
    # self.tax_amount = (self.dealer_invoice_items.sum(:central_tax_amount)+self.dealer_invoice_items.sum(:state_tax_amount)+self.dealer_invoice_items.sum(:inter_state_tax_amount))
    self.total_amount = (self.amount.to_f-self.discount_amount.to_f)+self.tax_amount.to_f
    self.save
  end

end
