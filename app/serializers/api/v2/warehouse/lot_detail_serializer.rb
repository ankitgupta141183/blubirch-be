class Api::V2::Warehouse::LotDetailSerializer < ActiveModel::Serializer
  attributes :id, :lot_name, :lot_desc, :quantity, :mrp, :floor_price, :reserve_price, :buy_now_price, :increment_slab, :start_date, :end_date, :bids, :active_bids

  has_many :liquidations

  def bids
    object.bids.unscope(where: :is_active)
  end

  def active_bids
    object.bids
  end

  def start_date
    object.start_date_with_localtime
  end

  def end_date
    object.end_date_with_localtime
  end
end
