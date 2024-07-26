class EWasteHistory < ApplicationRecord
	acts_as_paranoid
	belongs_to :e_waste
end
