class WarehouseOrderDocument < ApplicationRecord
	acts_as_paranoid
	mount_uploader :attachment ,  ConsignmentFileUploader
  belongs_to :attachable, polymorphic: true
end
