class PackedInventory < ApplicationRecord
	acts_as_paranoid
  belongs_to :packaging_box, optional: true
  belongs_to :inventory, optional: true
  belongs_to :user, optional: true

end
