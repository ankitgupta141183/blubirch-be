class TransferOrder < ApplicationRecord
  acts_as_paranoid
  has_many :restocks
  has_many :transfer_inventories
  has_many :warehouse_orders, as: :orderable
  validates_uniqueness_of :order_number, :case_sensitive => false, allow_blank: true
  
end
