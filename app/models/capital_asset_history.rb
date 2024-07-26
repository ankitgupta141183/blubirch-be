class CapitalAssetHistory < ApplicationRecord
	acts_as_paranoid
	belongs_to :capital_asset
end
