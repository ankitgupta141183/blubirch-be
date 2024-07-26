class CostValueSerializer < ActiveModel::Serializer
  attributes :id, :category_id, :cost_attribute_id, :brand, :model, :value
end
