class Ondc::OnConfirmService < Ondc::BaseService

  def initialize(params_data)
    @order_details = params_data["message"]["order"]
  end

  def on_confirm
    #! Questions
    #! 1. When order will be accpeted. because in params it is coming as 'Created'
    begin
      ActiveRecord::Base.transaction do
        order = store_order
        tags_data = []
        order.tags.each do |tag_d|
          tags_data << eval(tag_d) 
        end
    
        create_order_history(order.id, order.order_state)
        payload_with_context = {
          "context": {
            "domain": "ONDC:RET10",
            "action": "on_confirm",
            "core_version": "1.2.0",
            "bap_id": "buyerNP.com",
            "bap_uri": "https://buyerNP.com/ondc",
            "bpp_id": "sellerNP.com",
            "bpp_uri": "https://sellerNP.com/ondc",
            "transaction_id": "T2",
            "message_id": "M4",
            "city": "std:080",
            "country": "IND",
            "timestamp": "2023-06-03T09:30:30.000Z"
          },
          'message': {
            'order': {
              'id': order.id,
              'state': order.order_state,
              'provider': {
                "id": "P#{order.client_id}",
                "locations": [ #! How can we handle multiple locations
                  {
                    "id": "L#{order.distribution_center_id}"
                  }
                ],
                "rateable": true #! Given static
              },
              'billing': {
                "name": order.user_name,
                "address": order.user_address,
                "email": order.user_email,
                "phone": order.user_phone,
                "created_at": order.created_at,
                "updated_at": order.updated_at
              },
              'quote': {
                "price": {
                  "currency": order.currency,
                  "value": order.amount
                },
                "breakup": order.quote_breakup,
                'ttl': order.ttl,  #! Static data
              },
              'tags': (tags_data rescue []),
              'items': {},
              'payment': {},
              'fulfillments': [],
              "created_at": order.created_at,
              "updated_at": order.updated_at
            }
          }
        }
        
        order_items_data = store_order_items(order.id)
        payload_with_context[:message][:order][:items] = order_items_data
    
        order_payment = store_order_payment(order.id)
        payload_with_context[:message][:order][:payment] = order_payment.details
        
        order_fulfillment = store_order_fulfillment(order.id)
        payload_with_context[:message][:order][:fulfillments] << {
          "id": order_fulfillment.fulfillment_number,
          "@ondc/org/provider_name": order.client.name,
          "state": { #! Giving Static
              "descriptor": {
                  "code": "Pending"
              }
          },
          "type": order_fulfillment.fulfillment_type,
          "tracking": order_fulfillment.tracking,
          "start": order_fulfillment.store_details,
          "end": order_fulfillment.customer_details
        }
        payload_with_context
      end
    rescue => e
      raise e.backtrace
    end
  end

  def store_order
    begin
      ActiveRecord::Base.transaction do
        #? Intialize order
        order = OndcOrder.find_or_initialize_by(order_number: @order_details["id"])
        order.order_state = 'Accepted' #! Currently Made Accepted as Static
    
        #? Store Provider and Location Details
        order.client_id = @order_details['provider']['id'].gsub!('P', '')
        order.distribution_center_id = @order_details['provider']['locations'].first['id'].gsub!('L', '') #! Currently, considering only 1 location inside provider
    
        #? Store user details
        user_details = @order_details["billing"]
        order.assign_attributes({
          user_name: user_details['name'],
          user_address: user_details['address'],
          user_phone: user_details['phone'],
          user_email: user_details['email']
        })
    
        #? Store price and currency
        price_detals = @order_details['quote']['price']
        order.assign_attributes({
          amount: price_detals['value'],
          currency: price_detals['currency']
        })
    
        #? Store quote breakup
        order.quote_breakup = @order_details['quote']["breakup"]
    
        #? Store tags and ttl
        order_tags = []
        @order_details['tags'].each do |tags|
          order_tags << JSON.parse(tags.to_json)
        end
        order.tags = order_tags
        order.ttl = @order_details['quote']['ttl']
        order.save!
        order
      end
    rescue => e
      raise e.backtrace
    end
  end

  def store_order_items(order_id)
    begin
      order_items_data = []
      @order_details['items'].each do |item_data|
        ondc_item_id = item_data['id']
        order_item_detail_from_breakup = @order_details['quote']['breakup'].select{|d| d["@ondc/org/item_id"] = ondc_item_id }.first
        raise "no item detail with #{ondc_item_id} id is present" if order_item_detail_from_breakup.blank?
        inv_id = ondc_item_id.gsub!('I','')

        #? Initialize and store Ondc Order Item
        order_item = OndcOrderItem.find_or_initialize_by(inventory_id: inv_id.to_i, ondc_order_id: order_id.to_i)
        order_item.assign_attributes({
          quantity: item_data['quantity']['count'],
          price: order_item_detail_from_breakup['price']['value'],
          fulfillment_number: item_data['fulfillment_id']
        })
        order_item.save!
        order_items_data << {
          "id": ondc_item_id,
          "fulfillment_id": item_data['fulfillment_id'],
          "quantity": {
            "count": item_data['quantity']['count']
          }
        }
      end
      order_items_data
    rescue => e
      raise e.backtrace
    end
  end

  def store_order_payment(order_id)
    payment_details = @order_details["payment"]
    begin 
      ActiveRecord::Base.transaction do
        #? Intialize and Store Order Payment
        order_payment = OndcOrderPayment.find_or_initialize_by(ondc_order_id: order_id, transaction_number: payment_details['params']["transaction_id"])        
        order_payment.assign_attributes({
          currency: payment_details['params']['currency'],
          amount: payment_details['params']['amount'],
          status:  payment_details['status'],
          order_type: payment_details['type'],
          collected_by: payment_details['collected_by'],
          details: JSON.parse(payment_details.to_json)
        })

        order_payment.save!
        return order_payment
      end
    rescue => e
      raise e.backtrace
    end
  end

  def store_order_fulfillment(order_id)
    begin
      ActiveRecord::Base.transaction do  
        fulfillment_detail = @order_details['fulfillments'].first #! how to handle multiple fulfillments
        #? Initialize and store Order Fulfillment
        order_fulfillment = OndcOrderFulfillment.find_or_initialize_by(ondc_order_id: order_id, fulfillment_number: fulfillment_detail['id'])
        order_fulfillment.assign_attributes({
          fulfillment_type: fulfillment_detail['type'],
          tracking: fulfillment_detail['tracking'],
          customer_details: JSON.parse(fulfillment_detail['end'].to_json)
        })
        location = order_fulfillment.ondc_order.distribution_center

        order_fulfillment.customer_details["time"] = { #! Giving Static
          "range": {
              "start": "2023-06-03T11:00:00.000Z",
              "end": "2023-06-03T11:30:00.000Z"
          }
        }
        order_fulfillment.customer_details["instructions"] = { #! Giving Static
            "name": "Status for drop",
            "short_desc": "Delivery Confirmation Code"
        }

        order_fulfillment.store_details = {
          "location": {
              "id": location.id,
              "descriptor": {
                  "name": location.name
              },
              "gps": "12.956399,77.636803", #! Added static
              "address": {
                  "locality": location.address_line1,
                  "city": (location.city.original_code rescue 'Bengaluru'), #! Added rescue
                  "area_code": "560076", #! Added Static
                  "state": (location.state.original_code rescue 'KA') #! Added rescue
              }
          },
          "time": { #! Added static
              "range": {
                  "start": "2023-06-03T10:00:00.000Z",
                  "end": "2023-06-03T10:30:00.000Z"
              }
          },
          "instructions": { #! Added static
              "code": "2",
              "name": "ONDC order",
              "short_desc": "value of PCC",
              "long_desc": "additional instructions such as register or counter no for self-pickup"
          },
          "contact": { #! Added static
              "phone": "9886098860",
              "email": "nobody@nomail.com"
          }
        }
        order_fulfillment.save!
        return order_fulfillment
      end
    rescue => e
      raise e.backtrace
    end
  end

end