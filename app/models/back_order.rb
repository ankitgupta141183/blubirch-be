class BackOrder < ApplicationRecord

	belongs_to :saleable
	belongs_to :sale_order
	
	validates_uniqueness_of :order_number, :case_sensitive => false, allow_blank: true
end
