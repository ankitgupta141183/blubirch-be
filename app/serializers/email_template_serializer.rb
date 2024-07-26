class EmailTemplateSerializer < ActiveModel::Serializer
  
  attributes :id, :name, :template, :template_type, :deleted_at, :created_at, :updated_at

  def template_type
    LookupValue.where(id: object.template_type_id).last rescue nil
  end
  
end
