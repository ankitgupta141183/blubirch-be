class OndcOrder < ApplicationRecord

  has_many :ondc_order_items, dependent: :destroy
  has_many :ondc_order_fulfillments, dependent: :destroy
  has_many :ondc_order_payments, dependent: :destroy
  has_many :ondc_order_histories, dependent: :destroy

  belongs_to :client
  belongs_to :distribution_center

  validates_uniqueness_of :order_number

end
