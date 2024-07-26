class InsuranceOrder < ApplicationRecord
  acts_as_paranoid
  has_many :warehouse_orders, as: :orderable
  has_many :insurances
  validates_uniqueness_of :order_number, :case_sensitive => false, allow_blank: true
end
