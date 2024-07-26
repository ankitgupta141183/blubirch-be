class ReplacementHistory < ApplicationRecord
	acts_as_paranoid
  belongs_to :replacement
end
