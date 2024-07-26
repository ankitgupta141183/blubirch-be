class GradingRule < ApplicationRecord
	acts_as_paranoid
	has_many :category_grading_rules
	has_many :categories, through: :category_grading_rules

	has_many :client_category_grading_rules
	has_many :client_categories, through: :client_category_grading_rules
	
end
