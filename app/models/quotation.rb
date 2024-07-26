class Quotation < ApplicationRecord
  belongs_to :vendor_master
  belongs_to :liquidation_order
end
