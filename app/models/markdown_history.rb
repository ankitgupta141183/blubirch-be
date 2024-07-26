class MarkdownHistory < ApplicationRecord
	acts_as_paranoid
	belongs_to :markdown
end
