class OndcOrderItem < ApplicationRecord

  belongs_to :ondc_order
  belongs_to :inventory
  
end
