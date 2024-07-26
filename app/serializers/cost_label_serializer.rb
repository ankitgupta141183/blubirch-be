class CostLabelSerializer < ActiveModel::Serializer
	belongs_to :distribution_center
	belongs_to :channel
  attributes :id, :distribution_center_id, :channel_id, :label, :deleted_at

  def distribution_center
    object.distribution_center.name rescue nil
  end

  def channel
    object.channel.name rescue nil
  end
end
