class RentalHistory < ApplicationRecord
	acts_as_paranoid
	belongs_to :rental
end
