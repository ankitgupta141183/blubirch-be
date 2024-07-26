class RedeployOrder < ApplicationRecord
  acts_as_paranoid
  has_many :redeploys
  has_many :warehouse_orders, as: :orderable
  validates_uniqueness_of :order_number, :case_sensitive => false, allow_blank: true
  validates :lot_name, length: {is: 9}, allow_blank: true

  after_validation :add_errors_to_base, on: %i[create update]

  private

  def add_errors_to_base
    errors.add(:lot_name, "Lot Name should start with 8") if !lot_name.starts_with?('8')
  end
end