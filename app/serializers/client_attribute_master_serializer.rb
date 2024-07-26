class ClientAttributeMasterSerializer < ActiveModel::Serializer
	
  belongs_to :client
  attributes :id, :attr_type, :reason, :attr_label, :field_type, :options , :created_at, :updated_at, :deleted_at, :client_id

end
