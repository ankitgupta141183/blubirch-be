module UserSearchable
  extend ActiveSupport::Concern

  included do
    include PgSearch::Model
    pg_search_scope :search_by_text, against: [:first_name, :last_name], using: { tsearch: { prefix: true }  }
  end
end
