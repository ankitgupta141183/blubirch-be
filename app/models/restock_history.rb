class RestockHistory < ApplicationRecord
	acts_as_paranoid
	belongs_to :restock
end
