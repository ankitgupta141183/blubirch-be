module LiquidationOrderSearchable
  extend ActiveSupport::Concern

  included do
    include PgSearch::Model
    pg_search_scope :search_by_text, against: [:id, :lot_name, :lot_desc, :beam_lot_id], using: { tsearch: { any_word: true } }
  end
end
