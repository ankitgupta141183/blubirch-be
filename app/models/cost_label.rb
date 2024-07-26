class CostLabel < ApplicationRecord

	acts_as_paranoid
	belongs_to :distribution_center
	belongs_to :channel

		validates :label,  presence: true


	include Filterable
  scope :filter_by_distribution_center_id, -> (distribution_center_id) { where("distribution_center_id = ?", "#{distribution_center_id}")}
  scope :filter_by_channel_id, -> (channel_id) { where("channel_id = ?", "#{channel_id}")}
  scope :filter_by_label, -> (label) { where("label ilike ?", "%#{label}%")}

end
