class CannibalizationHistory < ApplicationRecord
	acts_as_paranoid
	belongs_to :cannibalization
end
