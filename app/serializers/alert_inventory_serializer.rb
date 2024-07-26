class AlertInventorySerializer < ActiveModel::Serializer

  attributes :id, :details, :location, :criticality, :created_at, :updated_at
  belongs_to :inventory
  
  def criticality
  	#LookupValue.find(object.alert_configuration.alert_type_id).code rescue ''
  	object.inventory.details["criticality"] rescue ''
  end

  def location
  	object.inventory.distribution_center.city.original_code rescue ''
  end

end
