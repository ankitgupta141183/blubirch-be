class ReplacementCustomerOrder < ApplicationRecord
	has_many :warehouse_orders, as: :orderable

	validates_uniqueness_of :order_number, :case_sensitive => false, allow_blank: true
end
