# frozen_string_literal: true

class AiPricingService

  attr_accessor :liquidation_order, :url, :headers

  def initialize(liquidation_order)
    username = Rails.application.credentials.ml_user
    password = Rails.application.credentials.ml_password
    @url = "#{Rails.application.credentials.ml_host}/inventory"
    @liquidation_order = liquidation_order
    @headers = "Basic " + Base64.strict_encode64("#{username}:#{password}").to_s
  end

  def call
    request_body = []
    inventories = liquidation_order.inventories.includes(:gate_pass_inventory, client_category: :seller_category)
    inventories.each do |inventory|
      inward_date = inventory.created_at.to_date.to_s
      category_hash = inventory.client_category.seller_category.details rescue {}
      grade = GradeMapping.find_by(client_item_name: inventory.grade)&.seller_item_name
      categoryL1 = categoryL2 = categoryL3 = 'Others'

      categoryL1 = category_hash["category_l1"].to_s if category_hash["category_l1"].present?
      categoryL2 = category_hash["category_l2"].to_s if category_hash["category_l2"].present?
      categoryL3 = category_hash["category_l3"].to_s if category_hash["category_l3"].present?
      request_body << {
        seller: 'Croma', categoryL1: categoryL1, categoryL2: categoryL2, categoryL3: categoryL3,
        categoryL4: category_hash["category_l4"].to_s, categoryL5: category_hash["category_l5"].to_s, categoryL6: category_hash["category_l6"].to_s,
        city: inventory.gate_pass&.source_city, inwardDate: inward_date, brand: inventory.gate_pass_inventory&.brand, model: 'model', mrp: liquidation_order.buy_now_price,
        functionalStatus: inventory.details["processed_grading_result"]["Functional"], physicalStatus: inventory.details["processed_grading_result"]["Physical Condition"],
        packagingStatus: inventory.details["processed_grading_result"]["Packaging Condition"], saleableStatus: inventory.details["processed_grading_result"]["Packaging Condition"],
        grade: grade, lotname: liquidation_order.lot_name, lotid: liquidation_order.id, tagNumber: inventory.tag_number, skuCode: inventory.sku_code,
        itemDescription: inventory.item_description, quantity: liquidation_order.quantity, totalNumber: liquidation_order.quantity
      }
    end
    request_hash = {
      lot_prices: request_body
    }
    headers_hash = {Authorization: @headers}
    headers_hash["Content-Type"] = 'application/json'
    begin
      response = RestClient::Request.execute(method: :post, url: url, payload: request_hash.to_json, verify_ssl: OpenSSL::SSL::VERIFY_NONE, headers: headers_hash)
    rescue => exception
      response = exception.response
    end
    response
  end

  def get_ai_prices
    headers_hash = {Authorization: @headers}
    headers_hash["Content-Type"] = 'application/json'
    url_with_tag_number = url + "?lot_id=#{liquidation_order.id}"
    begin
      response = RestClient::Request.execute(method: :get, url: url_with_tag_number, verify_ssl: OpenSSL::SSL::VERIFY_NONE, headers: headers_hash)
    rescue => exception
      response = exception.response
    end
    response
  rescue => e
    nil
  end
end
