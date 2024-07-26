module VendorReturnSearchable
  extend ActiveSupport::Concern

  included do
    include PgSearch::Model
    pg_search_scope :search_by_text, against: [:tag_number, :inventory_id], using: { tsearch: { any_word: true } }
  end
end
