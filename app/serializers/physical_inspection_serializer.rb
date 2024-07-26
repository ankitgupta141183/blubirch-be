class PhysicalInspectionSerializer < ActiveModel::Serializer
  
  attributes :id, :article_ids, :assignee_ids, :assignees_hash, :brands, :category_ids, :dispositions, :distribution_center_id, :inventory_type, :location, :request_id, :status, :created_at, :updated_at

  def status
    object.status == 'completed' ? 'Closed' : object.status
  end
  
  def location
    object.distribution_center&.code
  end
end
