class ReturnFileUploadSerializer < ActiveModel::Serializer

  attributes :id, :return_file_url, :return_type, :status, :user_id, :client_id, :remarks, :deleted_at, :created_at, :updated_at

  belongs_to :user

  def return_file_url
  	object.try(:return_file).try(:url)
  end

end
