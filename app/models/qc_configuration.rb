class QcConfiguration < ApplicationRecord
  acts_as_paranoid
  # filter logic starts
  include Filterable
  scope :filter_by_distribution_center_id, -> (distribution_center_id) { where("distribution_center_id = ?", "#{distribution_center_id}")}
  scope :filter_by_sample_percentage, -> (sample_percentage) { where("sample_percentage = ?", "#{sample_percentage}")}
  # filter logic ends

  belongs_to :distribution_center

  def self.create_qc_configurations
  	distribution_center = DistributionCenter.where("details ->> 'warehouse_code' = ?", "WH_001").first
  	QcConfiguration.create(sample_percentage: 10, distribution_center_id: distribution_center.try(:id))
  end

end
