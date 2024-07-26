class SaleOrder < ApplicationRecord

  has_many :warehouse_orders, as: :orderable
  has_many :saleables
  validates_uniqueness_of :order_number, :case_sensitive => false, allow_blank: true

end
