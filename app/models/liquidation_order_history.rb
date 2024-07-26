class LiquidationOrderHistory < ApplicationRecord
    acts_as_paranoid
    belongs_to :liquidation_order
end
