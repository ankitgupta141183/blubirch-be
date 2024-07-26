class DefectRule < ApplicationRecord
	acts_as_paranoid
  has_many :category_defect_rules
	has_many :client_categories, through: :category_defect_rules

end
