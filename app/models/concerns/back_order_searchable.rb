module BackOrderSearchable
  extend ActiveSupport::Concern

  included do
    include PgSearch::Model
    pg_search_scope :search_by_text, against: [:order_number], using: { tsearch: { any_word: true } }
  end
end
