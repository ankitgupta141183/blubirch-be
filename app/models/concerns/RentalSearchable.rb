module RentalSearchable
  extend ActiveSupport::Concern

  included do
    include PgSearch::Model
    pg_search_scope :search_by_text, against: [:tag_number, :article_sku, :buyer_name], using: { tsearch: { any_word: true } }
  end
end
