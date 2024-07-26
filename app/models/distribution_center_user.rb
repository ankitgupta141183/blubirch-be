class DistributionCenterUser < ApplicationRecord
	acts_as_paranoid
  belongs_to :user
  belongs_to :distribution_center
end
