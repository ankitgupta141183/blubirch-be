class VendorDistribution < ApplicationRecord
  belongs_to :vendor_master
  belongs_to :distribution_center
end
