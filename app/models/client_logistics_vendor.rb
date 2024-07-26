class ClientLogisticsVendor < ApplicationRecord

	has_many :vendor_site_mappings
  has_many :distribution_centers, through: :vendor_site_mappings, :source => :vendor_mappable, source_type: "Rapaas::DistributionCenter"

end
