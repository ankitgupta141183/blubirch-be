class DistributionCenterLocationSerializer < ActiveModel::Serializer

  attributes :id, :name, :code#, :selected_city, :selected_state, :selected_country, :country_based_states, :state_based_cities

  # def selected_city
  #   LookupValue.where(id: object.city_id).last rescue nil
  # end

  # def selected_state
  #   LookupValue.where(id: object.state_id).last rescue nil
  # end

  # def selected_country
  #   LookupValue.where(id: object.country_id).last rescue nil
  # end

  # def state_based_cities
  #   LookupValue.where(id: object.state_id).last.children rescue nil
  # end

  # def country_based_states
  #   LookupValue.where(id: object.country_id).last.children rescue nil
  # end
  def distribution_center_type
    LookupValue.where(id: object.distribution_center_type_id).last rescue nil
   end

end
