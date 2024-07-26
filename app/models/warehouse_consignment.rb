class WarehouseConsignment < ApplicationRecord
	acts_as_paranoid
  has_many :warehouse_order_documents, as: :attachable
end
