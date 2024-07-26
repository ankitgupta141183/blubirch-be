class MasterDataInput < ApplicationRecord

	has_many :gate_passes
	validates :payload, presence: true
	
end