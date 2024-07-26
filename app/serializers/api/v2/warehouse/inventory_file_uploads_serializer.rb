class Api::V2::Warehouse::InventoryFileUploadsSerializer < ActiveModel::Serializer
  attributes :id, :client_id, :created_at, :deleted_at, :inventory_file, :inward_type, :remarks, :status, :updated_at, :user_id, :error_file, :original_file

  def original_file
    object.inventory_file.url rescue 'NA'
  end

  def error_file
    object.error_file rescue nil
  end

  def updated_at
    object.updated_at.in_time_zone('Mumbai').strftime("%d.%m.%Y / %I:%M %p")
  end
end
