class DistributionCenterClient < ApplicationRecord
  
  acts_as_paranoid
  
  belongs_to :client
  belongs_to :distribution_center

end
