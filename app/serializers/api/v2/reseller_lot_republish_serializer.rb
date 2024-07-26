class Api::V2::ResellerLotRepublishSerializer < ActiveModel::Serializer
  attributes :lot_number, :old_lot_number, :lot_name, :floor_price, :reserve_price, :buy_now_price, :increment_slab, :start_date, :end_date, :mrp, :username, :approved_buyers_ids, :lot_description, :lot_image_urls, :quantity, :benchmark_price, :delivery_timeline, :bidding_method, :bid_value

  def initialize(object, options = {})
    @account_setting = options.dig(:adapter_options, :account_setting)
    @current_user = options.dig(:adapter_options, :current_user)
    super
  end

  def lot_description
    object.lot_desc
  end

  def lot_number
    object.id
  end

  def benchmark_price
    @account_setting.benchmark_price
  end

  def old_lot_number
    method_name = object.is_moq_lot? ? 'moq' : 'liquidation'
    object.send("parent_#{method_name}_order_id")
  end

  def bidding_method
    @current_user.bidding_method
  end

  def mrp
    object.liquidations.map(&:bench_mark_price).inject(:+)
  end

  def bid_value
    object.bid_value_multiple_of
  end

  def username
    if @account_setting.liquidation_lot_file_upload
      @current_user.username
    else
      @account_setting.username
    end
  end

  def start_date
    object.start_date_with_localtime
  end

  def end_date
    object.end_date_with_localtime
  end

  def approved_buyers_ids
    object.details&.dig('approved_buyer_ids') || []
  end
end
