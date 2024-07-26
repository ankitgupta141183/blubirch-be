class ConsignmentBoxImage < ApplicationRecord
  acts_as_paranoid
  belongs_to :consignment
  belongs_to :consignment_information
  
  mount_uploaders :damaged_images, ConsignmentFileUploader
  
  scope :good_boxes,    -> { where(is_damaged: false) }
  scope :damaged_boxes,  -> { where(is_damaged: true) }
  
end
