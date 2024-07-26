class OutboundDocumentArticle < ApplicationRecord

	acts_as_paranoid
  belongs_to :distribution_center
  belongs_to :client
  belongs_to :user, optional: true
  belongs_to :outbound_document, optional: true
  belongs_to :client_category, optional: true
  belongs_to :client_sku_master, optional: true
  belongs_to :outbound_document_article_status, class_name: "LookupValue", foreign_key: :status_id

  validates :item_number, :sku_code, :item_description, :quantity, :scan_id, presence: true

  has_many :outbound_inventories

end
