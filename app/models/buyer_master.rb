class BuyerMaster < ApplicationRecord
  include BuyerMasterSearchable
  include Filterable

  validates :username, :first_name, :last_name, presence: true
  validates :username, uniqueness: true

  default_scope { where(is_active: true) }

  def full_name
    "#{first_name} #{last_name}".split.map(&:capitalize).join(' ')
  end
end
