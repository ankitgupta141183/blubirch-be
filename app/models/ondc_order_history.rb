class OndcOrderHistory < ApplicationRecord

  belongs_to :ondc_order
  validates_presence_of :order_state
end
