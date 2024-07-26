# frozen_string_literal: true

class AiInventoryPricingService

  include SkuCodeQuery
  attr_accessor :inventories, :url, :headers, :ai_price


  def initialize(inventory_ids)
    @inventories = Inventory.where(id: inventory_ids).includes(:gate_pass_inventory, client_category: :seller_category)
    username = Rails.application.credentials.ml_user
    password = Rails.application.credentials.ml_password
    @url = "#{Rails.application.credentials.ml_host}/inventory"
    @headers = "Basic " + Base64.strict_encode64("#{username}:#{password}").to_s
  end

  def call
    ai_response = get_ai_reponse
    
    if ai_response.present?
      resp = JSON.parse(ai_response.body)
      price_hash = {}
      resp["prices"].each do |price|
        price_hash[price["tag_number"]] = price["ai_price"]
      end
      inventories.each do |inventory|
        price = price_hash[inventory.tag_number]
        next if price.blank?

        inventory.details["ai_price"] = price
        inventory.details["ai_price_updated_at"] = Time.now
        inventory.save
      end
    end
  end

  def validate_inventories
    errors = []
    inventories.each do |inventory|
      functional_status = inventory.details["processed_grading_result"]["Functional"] rescue ''
      physical_status = inventory.details["processed_grading_result"]["Physical Condition"] rescue ''
      packaging_status = inventory.details["processed_grading_result"]["Packaging Condition"] rescue ''
      grade = GradeMapping.find_by(client_item_name: inventory.grade)&.seller_item_name
      # item = Item.where(build_sku_code_query(inventory.sku_code.downcase)).last
      errors << "Tag Number cannot be blank" if inventory.tag_number.blank?
      errors << "City cannot be blank" if inventory.distribution_center&.city&.original_code.blank?
      # errors << "Brand cannot be blank" if item.blank? || item.present? && item.brand.blank?
      errors << "MRP cannot be blank" if inventory.item_price.blank?
      # errors << "Functional Status cannot be blank" if functional_status.blank?
      # errors << "Physical Status cannot be blank" if physical_status.blank?
      # errors << "Packaging Status cannot be blank" if packaging_status.blank?
      errors << "Grade cannot be blank" if grade.blank?
      break if errors.present?
    end
    errors
  end

  def get_ai_reponse
    request_body = []
    inventories.each do |inventory|
      next if inventory.details["ai_price"].present?

      inward_date = inventory.created_at.to_date.to_s
      category_hash = inventory.client_category.seller_category.details rescue {}
      grade = GradeMapping.find_by(client_item_name: inventory.grade)&.seller_item_name
      item = Item.where(build_sku_code_query(inventory.sku_code.downcase)).last
      categoryL1 = categoryL2 = categoryL3 = 'Others'

      categoryL1 = category_hash["category_l1"].to_s if category_hash["category_l1"].present?
      categoryL2 = category_hash["category_l2"].to_s if category_hash["category_l2"].present?
      categoryL3 = category_hash["category_l3"].to_s if category_hash["category_l3"].present?
      functional_status = inventory.details["processed_grading_result"]["Functional"] rescue ''
      physical_status = inventory.details["processed_grading_result"]["Physical Condition"] rescue ''
      packaging_status = inventory.details["processed_grading_result"]["Packaging Condition"] rescue ''
      saleable_status = inventory.details["processed_grading_result"]["Packaging Condition"] rescue ''

      request_body << {
        seller: 'Croma', categoryL1: categoryL1, categoryL2: categoryL2, categoryL3: categoryL3,
        categoryL4: category_hash["category_l4"].to_s, categoryL5: category_hash["category_l5"].to_s, categoryL6: category_hash["category_l6"].to_s,
        city: inventory.distribution_center&.city&.original_code, inwardDate: inward_date, brand: item&.brand, model: 'model', mrp: inventory.item_price,
        functionalStatus: functional_status, physicalStatus: physical_status,
        packagingStatus: packaging_status, saleableStatus: saleable_status,
        grade: grade, tagNumber: inventory.tag_number, skuCode: inventory.sku_code,
        itemDescription: inventory.item_description, quantity: inventory.quantity, totalNumber: inventory.quantity
      }
    end
    response = nil
    if request_body.present?
      request_hash = {
        lot_prices: request_body
      }
      headers_hash = {Authorization: @headers}
      headers_hash["Content-Type"] = 'application/json'
      begin
        response = RestClient::Request.execute(method: :post, url: url, payload: request_hash.to_json, verify_ssl: OpenSSL::SSL::VERIFY_NONE, headers: headers_hash)
      rescue => exception
        response = exception.response
        Rails.logger.info(response.body)
      end
    end
    response
  end

  def calculate_prices
    @ai_price = 0.0
    @price = 0.0
    inventories.reload.each do |inventory|
      @ai_price += inventory.details["ai_price"].to_f
      @price += calculate_buy_now_price(inventory)
    end
    start_time = CommonUtils.get_current_local_time + 15.minutes
    start_time = Time.at((start_time.to_f / 15.minutes).round * 15.minutes).in_time_zone('Mumbai')
    end_time = start_time + 24.hours
    {
      floor_price: floor_price, start_time: start_time.strftime('%d/%m/%Y %H:%M %p'), 
      end_time: end_time.strftime('%d/%m/%Y %H:%M %p'), buy_now_price: buy_now_price, 
      reserve_price: reserve_price, bid_increment_price: bid_increment_price, delivery_days: 7, 
      bid_multiple: bid_multiple
    }
  end

  def calculate_buy_now_price(inventory)
    if ['A1', 'AA'].include?(inventory.grade)
      (inventory.item_price * 98)/100
    elsif inventory.grade == 'A'
      (inventory.item_price * 95)/100
    else
      (inventory.item_price * 90)/100
    end
  end

  def calculate_standard_deviation(numbers)
    n = numbers.length
    mean = numbers.sum / n.to_f
    sum_of_squared_differences = numbers.map { |x| (x - mean) ** 2 }.sum
    variance = sum_of_squared_differences / n.to_f
    Math.sqrt(variance)
  end

  def buy_now_price
    liquidation_order_ids = []
    inventories = Inventory.includes(liquidation: :liquidation_order).where("details ->> 'ai_price' is not NULL")
    inventories.each do |inv|
      liquidation_order_ids << inv.liquidation.liquidation_order.id if inv.liquidation.present? && inv.liquidation.liquidation_order.present?
    end
    if liquidation_order_ids.uniq.size > 30
      liquidations = LiquidationOrder.includes(liquidations: :inventory).where(id: liquidation_order_ids).where("winner_amount is not null").order("id desc").limit(30)
      differences = []
      liquidations.each do |liquidation|
        total_price = 0.0
        liquidation.liquidations.each do |liq|
          total_price += liq.inventory.details["ai_price"].to_f
        end
        differences << (total_price.to_f - liquidation.winner_amount.to_f)
      end
      mean = calculate_mean(differences)
      sd_price = calculate_standard_deviation(differences).to_i * 3
      mrp_price = ((@price * 98)/100).to_i
      calculated_price = round_off_value(@price + mean + (3 * sd_price))
      calculated_price < mrp_price ? calculated_price : mrp_price
    else
      @price
    end
  end

  def calculate_mean(array)
    sum = array.reduce(:+)
    mean = sum.to_f / array.length
  end

  def floor_price
    round_off_value((ai_price * 80)/100)
  end

  def reserve_price
    round_off_value((ai_price * 98)/100)
  end

  def bid_increment_price
    price = if ai_price > 2000000
      100000
    elsif ai_price > 1000000
      50000
    elsif ai_price > 500000
      20000
    elsif ai_price > 100000
      10000
    else
      1000
    end
  end

  def bid_multiple
    if ai_price > 2000000
      10000
    elsif ai_price > 100000
      10000
    elsif ai_price > 1000
      1000
    else
      1
    end
  end

  def round_off_value(number)
    if number > 2000000
      (number.div(100000)) * 100000
    elsif number > 1000000
      (number.div(50000)) * 50000
    elsif number > 500000
      (number.div(20000)) * 20000
    elsif number > 100000
      (number.div(10000)) * 10000
    elsif number > 10000
      (number.div(1000)) * 1000
    else 
      (number.div(100)) * 100
    end
  end
end