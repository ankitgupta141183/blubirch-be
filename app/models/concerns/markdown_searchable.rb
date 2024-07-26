module MarkdownSearchable
  extend ActiveSupport::Concern

  included do
    include PgSearch::Model
    pg_search_scope :search_by_text, against: [:sku_code, :item_description], using: { tsearch: { any_word: true } }
  end
end
