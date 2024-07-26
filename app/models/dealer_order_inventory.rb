class DealerOrderInventory < ApplicationRecord
	acts_as_paranoid
  # filter logic starts
  include Filterable
  scope :filter_by_sku_master_code, -> (sku_master_code) { where("sku_master_code ilike ?", "%#{sku_master_code}%")}
  scope :filter_by_item_description, -> (item_description) { where("item_description = ?", "%#{item_description}%")}
  # filter logic ends

end
