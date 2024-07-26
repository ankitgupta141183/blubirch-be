class OutboundInventory < ApplicationRecord

	acts_as_paranoid
  belongs_to :distribution_center
  belongs_to :client
  belongs_to :user, optional: true
  belongs_to :outbound_document, optional: true
  belongs_to :outbound_document_article, optional: true
  belongs_to :client_category, optional: true
  belongs_to :inventory_status, class_name: "LookupValue", foreign_key: :status_id

  include Filterable
  include JsonUpdateable
  # validates_uniqueness_of :tag_number, :case_sensitive => false, allow_blank: true
  validates_length_of :tag_number, minimum: 5

end
