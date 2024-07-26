class SkuEan < ApplicationRecord
  
  belongs_to :client_sku_master, optional: true
  validates :ean, uniqueness: {scope: :client_sku_master_id}  
  
end
