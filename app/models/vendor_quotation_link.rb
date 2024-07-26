class VendorQuotationLink < ApplicationRecord
  belongs_to :vendor_master
  belongs_to :liquidation_order

  validates :liquidation_order_id, :vendor_master_id, presence: true

  def expired?
  	Time.now.in_time_zone('Mumbai').to_datetime.strftime("%d/%b/%Y - %I:%M %p").to_datetime > expiry_date.to_datetime.strftime("%d/%b/%Y - %I:%M %p").to_datetime
  end

end
