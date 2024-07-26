class BomMapping < ApplicationRecord
  acts_as_paranoid
  belongs_to :client_sku_master
  belongs_to :bom_article, class_name: "ClientSkuMaster"
  
end
