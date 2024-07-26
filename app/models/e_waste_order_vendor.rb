class EWasteOrderVendor < ApplicationRecord
    # acts_as_paranoid
    belongs_to :e_waste_order
    belongs_to :vendor_master
end
