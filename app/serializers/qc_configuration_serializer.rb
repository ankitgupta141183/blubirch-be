class QcConfigurationSerializer < ActiveModel::Serializer

  belongs_to :distribution_center
  attributes :id, :distribution_center_id, :sample_percentage, :created_at, :updated_at
  
end
