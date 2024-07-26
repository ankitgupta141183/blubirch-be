class MasterFileUploadSerializer < ActiveModel::Serializer
  include Utils::Formatting
  attributes :id, :master_file, :master_file_type, :filename, :status, :remarks, :created_at, :updated_at, :client, :retry_enabled, :user_name

  # belongs_to :user
  # belongs_to :client, optional: true

  def filename
    object.master_file.file.filename rescue nil
  end

  def client
    object.client&.name
  end

  def retry_enabled
    !object.retrying? && object.retry_rows.any?
  end
  
  def created_at
    format_ist_time(object.created_at)
  end
  
  def updated_at
    format_ist_time(object.updated_at)
  end
  
  def user_name
    object.user&.username
  end
end
