class VendorSiteMapping < ApplicationRecord

	belongs_to :vendor_mappable, polymorphic: true
  belongs_to :distribution_center, optional: true

  validates :vendor_location, presence: true
  
end
