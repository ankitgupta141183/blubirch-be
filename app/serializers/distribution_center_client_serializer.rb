class DistributionCenterClientSerializer < ActiveModel::Serializer
  belongs_to :client
  belongs_to :distribution_center
  attributes :id, :client_id, :distribution_center_id, :deleted_at, :created_at, :updated_at, :client, :distribution_center

  def client
    object.client.name rescue nil
  end

  def distribution_center
    object.distribution_center.name rescue nil
  end
end
