module VendorMasterSearchable
  extend ActiveSupport::Concern

  included do
    include PgSearch::Model
    # pg_search_scope :search_by_text, against: [:vendor_code, :vendor_email, :vendor_name], using: { tsearch: { any_word: true } }
    pg_search_scope :search_by_text, against: [:vendor_code, :vendor_email, :vendor_name], using: { tsearch: { prefix: true } }
  end
end
