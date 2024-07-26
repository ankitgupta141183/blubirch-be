class ChannelSerializer < ActiveModel::Serializer

	belongs_to :distribution_center
  attributes :id, :name, :distribution_center_id, :cost_formula, :revenue_formula, :recovery_formula, :created_at, :updated_at, :deleted_at, :distribution_center

  def distribution_center
    object.distribution_center.name rescue nil
  end
end
