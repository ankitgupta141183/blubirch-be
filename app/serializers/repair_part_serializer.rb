class RepairPartSerializer < ActiveModel::Serializer

  attributes :id, :details, :name, :part_number, :is_active, :price, :hsn_code, :created_at, :updated_at, :deleted_at

end
