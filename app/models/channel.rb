class Channel < ApplicationRecord
	acts_as_paranoid

	belongs_to :distribution_center

	  validates :name,  presence: true

	# filter logic starts
  include Filterable
  scope :filter_by_name, -> (name) { where("name ilike ?", "%#{name}%")}
  scope :filter_by_distribution_center_id, -> (distribution_center_id) { where("distribution_center_id = ?", "#{distribution_center_id}")}
  # filter logic ends

	has_many :cost_labels
end
