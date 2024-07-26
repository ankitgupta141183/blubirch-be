class ReturnDocumentInventory < ApplicationRecord

	acts_as_paranoid
  belongs_to :distribution_center
  belongs_to :client
  belongs_to :user, optional: true
  belongs_to :return_document, optional: true
  belongs_to :client_category, optional: true
  belongs_to :client_sku_master, optional: true
  belongs_to :gate_pass_inventory_status, class_name: "LookupValue", foreign_key: :status_id

end
