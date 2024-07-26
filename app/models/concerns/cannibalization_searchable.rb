module CannibalizationSearchable
  extend ActiveSupport::Concern

  included do
    include PgSearch::Model
    pg_search_scope :search_by_text, against: [:tag_number, :sku_code], using: { tsearch: { any_word: true } }
  end
end
