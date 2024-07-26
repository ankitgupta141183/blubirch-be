class LiquidationHistory < ApplicationRecord
	acts_as_paranoid
  belongs_to :liquidation
  


end