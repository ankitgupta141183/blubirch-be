class InventorySerializer < ActiveModel::Serializer
  
  has_many :inventory_grading_details

  attributes :id, :distribution_center_id, :grade_send, :grade_received, :user_name, :inventory_grading_details, :client_id, :user_id, :tag_number, :details,  :created_at, :updated_at, :deleted_at, :origin_station, :destination_station, :city_name, :location_code, :aging, :origin, :destination, :brand

  def origin_station
    object.distribution_center.address
  end

  def grade_send
    if object.inventory_grading_details.present?
      LookupValue.where(id: object.inventory_grading_details.first.grade_id).last.original_code
    end
  end

  def grade_received
    if object.inventory_grading_details.present?
      LookupValue.where(id: object.inventory_grading_details.last.grade_id).last.original_code
    end
  end

  def user_name
    object.user.full_name
  end

  def destination_station
    object.client.address
  end

  def origin
    object.distribution_center.details["vendor_code"].present? ? object.distribution_center.details["vendor_code"] : "BLR_001"
  end

  def destination
    object.client.details['warehouse_code']
  end

  def city_name
    object.distribution_center.city.original_code rescue nil
  end

  def location_code
    object.distribution_center.details["warehouse_code"].present? ? object.distribution_center.details["warehouse_code"] : "SBD_WH_001"
  end

  def aging
    object.details["approval_sent_date"].present? ? TimeDifference.between(object.details["approval_sent_date"] , Time.now.to_s).in_days.ceil : TimeDifference.between(object.updated_at , Time.now.to_s).in_days.ceil
  end

  def brand
    ["Black & Decker", "Bosch"].sample
  end


end
