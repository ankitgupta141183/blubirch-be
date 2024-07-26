class AlertInventory < ApplicationRecord
	acts_as_paranoid
	belongs_to :inventory
	belongs_to :alert_configuration
end
