class PackagingBox < ApplicationRecord
  acts_as_paranoid
  belongs_to :distribution_center
  belongs_to :user

  has_many :packed_inventories, autosave: true

  has_many :gate_pass_boxes
  has_many :gate_passes, through: :gate_pass_boxes

  after_commit :assign_box_number

  private

  def assign_box_number
    self.update_column('box_number', "BX_#{id}") if self.box_number.blank?
  end

end
