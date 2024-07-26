class LotDetailSerializer < ActiveModel::Serializer
  attributes :id, :lot_name, :lot_desc, :quantity, :mrp, :floor_price, :ai_price, :reserve_price, :buy_now_price, :increment_slab, :start_date, :end_date, :bids, :active_bids, :billing_to_items

  has_many :liquidations

  def bids
    object.bids.unscope(where: :is_active)
  end

  def active_bids
    object.bids
  end

  def billing_to_items
    VendorMaster.where(vendor_name: "Green Enabled IT Solutions").map{|obj| { id: obj.id, vendor_name: obj.vendor_name } }
  end

  def start_date
    object.start_date_with_localtime.strftime("%d/%b/%Y %I:%M %P").to_datetime.utc rescue object.start_date
  end

  def end_date
    object.end_date_with_localtime.strftime("%d/%b/%Y %I:%M %P").to_datetime.utc rescue object.end_date
  end
end
