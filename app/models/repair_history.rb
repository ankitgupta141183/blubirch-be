class RepairHistory < ApplicationRecord
	acts_as_paranoid
	belongs_to :repair
end