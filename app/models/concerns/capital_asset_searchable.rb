module CapitalAssetSearchable
  extend ActiveSupport::Concern

  included do
    include PgSearch::Model
    pg_search_scope :search_by_text, against: [:tag_number, :article_sku, :assignment_status], using: { tsearch: { any_word: true } }
  end
end
