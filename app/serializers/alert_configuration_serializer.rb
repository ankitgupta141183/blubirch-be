class AlertConfigurationSerializer < ActiveModel::Serializer

  attributes :id, :details, :type, :created_at, :updated_at, :deleted_at

  def type
  	LookupValue.find(object.alert_type_id).code
  end

end
