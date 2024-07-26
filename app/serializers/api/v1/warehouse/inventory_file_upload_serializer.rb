class Api::V1::Warehouse::InventoryFileUploadSerializer < ActiveModel::Serializer
  attributes :id, :inventory_file, :status, :remarks, :user_id, :client_id, :deleted_at, :created_at, :updated_at, :inward_type

  def remarks
    object.remarks.split(",") rescue [] 
  end

end
