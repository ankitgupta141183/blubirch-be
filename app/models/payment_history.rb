class PaymentHistory < ApplicationRecord
  belongs_to :payable, polymorphic: true
  belongs_to :user

  validates_presence_of :amount, :paid_user, :payment_date
end
