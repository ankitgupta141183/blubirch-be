class InventoryStatus < ApplicationRecord
	acts_as_paranoid
	belongs_to :inventory
	belongs_to :distribution_center
	belongs_to :user, optional: true
	belongs_to :status, class_name: "LookupValue", foreign_key: :status_id

	include JsonUpdateable

end
