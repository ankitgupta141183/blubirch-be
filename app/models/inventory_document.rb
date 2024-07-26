class InventoryDocument < ApplicationRecord
	mount_uploader :attachment ,  ConsignmentFileUploader
  belongs_to :inventory
 	acts_as_paranoid
end
