class EWasteOrder < ApplicationRecord
	acts_as_paranoid
	has_many :e_wastes
	has_many :warehouse_orders , as: :orderable
	has_many :e_waste_order_histories, dependent: :destroy
end
