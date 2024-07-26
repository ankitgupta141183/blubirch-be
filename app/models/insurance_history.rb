class InsuranceHistory < ApplicationRecord
	acts_as_paranoid
  belongs_to :insurance
end
