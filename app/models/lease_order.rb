class LeaseOrder < ApplicationRecord
  has_many :warehouse_orders, as: :orderable
  has_many :rentals
  validates_uniqueness_of :order_number, :case_sensitive => false, allow_blank: true
end
