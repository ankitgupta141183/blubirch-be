class CustomerReturnReasonSerializer < ActiveModel::Serializer

  attributes :id, :name, :grading_required, :deleted_at, :created_at, :updated_at
  
end
