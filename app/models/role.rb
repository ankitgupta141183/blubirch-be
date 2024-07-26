class Role < ApplicationRecord

  # filter logic starts
  include Filterable
  scope :filter_by_name, -> (name) { where("name ilike ?", "%#{name}%")}
  scope :filter_by_code, -> (code) { where("code ilike ?", "%#{code}%")}
  # filter logic ends

  has_logidze
  acts_as_paranoid
  has_many :user_roles
  has_many :users, through: :user_roles

  validates :name, presence: true, uniqueness: true

end
