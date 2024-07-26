class ClientCategoryGradingRuleSerializer < ActiveModel::Serializer

	attributes :id, :test_rule_id, :grading_rule_id, :client_category_id, :category_name, :grading_type

	def category_name
		object.client_category.name
	end

end
