class Api::V2::ResellerLotPublishSerializer < ActiveModel::Serializer
  attributes :floor_price, :reserve_price, :buy_now_price, :increment_slab, :mrp, :start_date, :end_date, :lot_name, :lot_description, :lot_number, :lot_image_urls, :quantity, :benchmark_price, :delivery_timeline, :approved_buyers_ids, :bidding_method, :bid_value, :username, :inventories, :order_number

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

  def approved_buyers_ids
    object.details&.dig('approved_buyer_ids') || []
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

  def inventories
    inv = []
    if object.liquidations.present?
      hide_floor_price = object.liquidations.where('floor_price IS NULL OR floor_price = 0').any?
      object.liquidations.each do |liquidation|
        if liquidation.inventory.present?
          inventory = liquidation.inventory
          seller_category = if @account_setting.liquidation_lot_file_upload
            inventory.details
          else
            inventory.client_category.seller_category.details rescue {}
          end
          packaging_status = inventory.details["Packaging status"]
          functional_status = inventory.details["Functional status"]
          physical_status = inventory.details["Physical status"]
          accessories_status = inventory.details["Accessories"] || inventory.details["processed_grading_result"]["Accessories"] rescue ''
          inv << {
            sku_code: inventory.sku_code,
            tag_number: inventory.tag_number,
            name: inventory.item_description,
            category_l1: seller_category["category_l1"],
            category_l2: seller_category["category_l2"],
            category_l3: seller_category["category_l3"],
            category_l4: seller_category["category_l4"],
            category_l5: seller_category["category_l5"],
            category_l6: seller_category["category_l6"],
            price: inventory.item_price,
            special_price: inventory.item_price,
            title: inventory.item_description,
            brand: inventory.details["brand"] || inventory.details['Brand'],
            quantity: inventory.quantity,
            inventory_grade: (GradeMapping.find_by(client_item_name: inventory.grade)&.seller_item_name || inventory.grade),
            remarks: inventory.remarks,
            description: inventory.item_description,
            short_description: inventory.item_description,
            serial_number: inventory.serial_number,
            city: inventory.details['City'] || inventory.distribution_center&.city&.original_code,
            sub_model_variant: inventory.details["Sub-Model/ Variant"],
            packaging_status: packaging_status,
            functional_status: functional_status,
            model: inventory.details["Model"],
            item_description_as_per_candidate_file: inventory.details["Item Description As per candidate file"],
            inventory_id: inventory.details["Inventory ID"],
            floor_price: hide_floor_price ? nil : liquidation.floor_price.to_i,
            other_details: inventory.details,
            physical_status: physical_status,
            accessories_status: accessories_status
          }
        end
      end
    end
    return inv
  end

  def start_date
    object.start_date_with_localtime
  end

  def end_date
    object.end_date_with_localtime
  end
end
