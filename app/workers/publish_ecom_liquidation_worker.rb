class PublishEcomLiquidationWorker
  include Sidekiq::Worker
  include Utils::Formatting

  def perform(ecom_liquidation_ids)
    ecom_liquidations = EcomLiquidation.where(id: ecom_liquidation_ids)

    ecom_liquidations.each do |ecom_liquidation|

      #& Request Payload for Publish
      liquidation = ecom_liquidation.liquidation
      user = ecom_liquidation.user
      seller_category = liquidation.client_category.seller_category.details
      assessent_details = liquidation.details["processed_grading_result"]
      payload = {
        item: {
          name: liquidation.item_description,
          tag_number: liquidation.tag_number,
          sku: liquidation.sku_code,
          liquidation_id: liquidation.id,
          description: liquidation.item_description,
          short_description: liquidation.item_description,
          quantity: 1, #! Default quantity
          mrp: ecom_liquidation.amount,
          special_price: ecom_liquidation.amount,
          online_selling_price: ecom_liquidation.amount,
          grade: liquidation.grade,
          brand: liquidation.brand,
          details_1: "",
          details_2: "",
          product_specification_1: "",
          product_specification_2: "",
          product_specification_3: "",
          product_specification_4: "",
          product_specification_5: "",
          bmaxx_assessment_1: assessent_details["Item Condition"],
          bmaxx_assessment_2: assessent_details["Physical Condition"],
          bmaxx_assessment_3: assessent_details["Packaging Condition"],
          bmaxx_assessment_4: "",
          category_l1: seller_category['bmaxx_parent'],
          category_l2: seller_category['bmaxx_child'],
          category_l3: seller_category['bmaxx_child'],
          external_item_id: ecom_liquidation.id,
          city: (liquidation.inventory.gate_pass.destination_city rescue nil),
          images: ecom_liquidation.ecom_images.present? ? ecom_liquidation.ecom_images.map(&:url) : []
        }
      }
      url = Rails.application.credentials.bmaxx_url + '/rims/items'
      method = :post

      #& Creating Ecom Request History
      ecom_request_history = liquidation.ecom_request_histories.create!(liquidation: liquidation, status: :sent, response_body: payload)

      begin
        ActiveRecord::Base.transaction do
          response = EcomLiquidation.send_request_ext_platform(method, url, payload)
          if response.code == 200
            resp_body = JSON.parse(response.body)
            ecom_liquidation.external_request_id = resp_body['item_id']
            ecom_liquidation.publish_status = :publish_approval
            ecom_liquidation.details = {}
            ecom_liquidation.details['approved_by'] = user.full_name
            ecom_liquidation.details['approved_at'] = format_date(DateTime.now, :p_long)
            ecom_request_history.update!(status: :success, response_data: resp_body)
            ecom_liquidation.platform_response = resp_body
            status = LookupValue.where(original_code: 'Pending B2C Publish').first
            liquidation.update!(b2c_publish_status: Liquidation.b2c_publish_statuses[:publish_approval], status: status.original_code, status_id: status.id)   
            liquidation.reload
            liquidation.inventory.update_inventory_status!(status)
            liquidation.create_history(user)
            raise 'vendor code cannot be blank for liquidation' if ecom_liquidation.vendor_code.blank?
            ecom_liquidation.vendor_name = VendorMaster.find_by_vendor_code(ecom_liquidation.vendor_code).vendor_name
            ecom_liquidation.save!
          else
            resp_body = JSON.parse(response.body)
            ecom_request_history.update!(status: :failed, response_data: resp_body['error'])
            ecom_liquidation.update!(publish_status: :failed, platform_response: resp_body['error'])
            liquidation.update!(b2c_publish_status: Liquidation.b2c_publish_statuses[:failed])
          end
        end
      rescue => exc
        exc_message = (JSON.parse(exc.response.body) rescue exc.message)
        ecom_request_history.update!(status: :failed, response_data:  "Error: #{exc_message} || Backtrace: #{exc.backtrace.to_s.truncate(1000)}")
        ecom_liquidation.update!(publish_status: :failed, platform_response: exc_message.to_json)
        liquidation.update!(b2c_publish_status: Liquidation.b2c_publish_statuses[:failed])
      end

    end
  end
end