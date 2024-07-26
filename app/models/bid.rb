class Bid < ApplicationRecord
  default_scope { where(is_active: true) }

  belongs_to :liquidation_order ,optional: true
end
