class EcomPurchaseHistory < ApplicationRecord

  belongs_to :ecom_liquidation

  enum status: { ordered: 1, cancelled: 2 }, _prefix: true

  validates_presence_of :amount, :quantity, :username, :order_number, :status

end
