class LiquidationRequest < ApplicationRecord
  has_many :liquidations
  has_many :liquidation_orders

  before_save :check_status_and_item_count

  def request_number
    number = "R-#{SecureRandom.hex(3)}".downcase
    item = LiquidationRequest.where(request_id: number)
    while item.present? do
      number = "R-#{SecureRandom.hex(3)}".downcase
      item = LiquidationRequest.where(request_id: number)
    end
    return number
  end

  def release_liquidation
    update(total_items: (total_items - 1), graded_items: (graded_items - 1))
  end

  def add_liquidation
    update(total_items: (total_items + 1), graded_items: (graded_items + 1))
  end

  private

  def check_status_and_item_count
    if (graded_items == total_items) && graded_items_changed?
      sts = LookupValue.find_by(code: 'request_status_fully_graded')
      status = sts.original_code
      status_id = sts.id
    end
  end
end