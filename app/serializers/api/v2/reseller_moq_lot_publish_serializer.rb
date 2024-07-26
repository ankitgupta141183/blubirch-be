class Api::V2::ResellerMoqLotPublishSerializer < ActiveModel::Serializer
  attributes :maximum_lots_per_buyer, :moq_order_id, :lot_order, :status, :lot_type, :mrp, :start_date, :end_date, :lot_name, :lot_description, :lot_number, :quantity, :benchmark_price, :delivery_timeline, :approved_buyers_ids, :bidding_method, :username, :inventories, :sub_lot_numbers, :lot_range, :lot_image_urls

  def initialize(object, options = {})
    @account_setting = options.dig(:adapter_options, :account_setting)
    @current_user = options.dig(:adapter_options, :current_user)
    super
  end

  def start_date
    object.start_date_with_localtime
  end

  def end_date
    object.end_date_with_localtime
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

  def approved_buyers_ids
    object.details&.dig('approved_buyer_ids') || []
  end

  def bidding_method
    object.is_moq_lot? ? 'moq' : @current_user.bidding_method
  end

  def username
    if @account_setting.liquidation_lot_file_upload
      @current_user.username
    else
      @account_setting.username
    end
  end

  def inventories
    inventory_record = []
    object.liquidations.group_by{|liquidation| [liquidation.sku_code, liquidation.grade]}.each do |key, value|
      inventory = value.find { |v| break v.inventory if v.inventory.present? }
      next unless inventory.present?
      seller_category = inventory.client_category.seller_category.details rescue {}
      inventory_record << {
        sku_code: inventory.sku_code,
        name: inventory.item_description,
        category_l1: seller_category['category_l1'],
        category_l2: seller_category['category_l2'],
        category_l3: seller_category['category_l3'],
        category_l4: seller_category['category_l4'],
        category_l5: seller_category['category_l5'],
        category_l6: seller_category['category_l6'],
        price: inventory.item_price,
        special_price: inventory.item_price,
        title: inventory.item_description,
        brand: inventory.details&.dig('brand'),
        quantity: value.size/object.moq_sub_lots.size,
        inventory_grade: (GradeMapping.find_by(client_item_name: inventory.grade)&.seller_item_name || inventory.grade),
        remarks: inventory.remarks,
        description: inventory.item_description,
        short_description: inventory.item_description,
        serial_number: inventory.serial_number,
        city: inventory.distribution_center&.city&.original_code,
      }
    end
    return inventory_record
  end

  def sub_lot_numbers
    object.moq_sub_lots.pluck(:id).uniq.compact
  end

  def lot_range
    object.moq_sub_lot_prices.map{|sub_lot_price| {from_lot: sub_lot_price.from_lot, to_lot: sub_lot_price.to_lot, price_per_lot: sub_lot_price.price_per_lot}}
  end

  def quantity
    object.moq_sub_lots.size
  end
end
