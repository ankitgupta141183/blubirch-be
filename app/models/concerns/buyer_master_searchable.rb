module BuyerMasterSearchable
  extend ActiveSupport::Concern

  included do
    include PgSearch::Model
    pg_search_scope :search_by_text, against: [:username, :email, :first_name, :last_name], using: { tsearch: { any_word: true } }
  end
end
