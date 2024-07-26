class EWasteOrderHistory < ApplicationRecord
    acts_as_paranoid
    belongs_to :e_waste_order
end
