class Ondc::OnCancelService < Ondc::BaseService

  def initialize(params)
    order_number =  params['message']['order_id']
    @cancellation_reason_id = params['message']['cancellation_reason_id']
    @order = OndcOrder.find_by(order_number: order_number)
    @order_fulfillments = @order.ondc_order_fulfillments

    @price_with_ids = []

    @payload_with_context = {
      "context": {
        "domain": "ONDC:RET10",
        "country": "IND",
        "city": "std:080",
        "action": "on_cancel",
        "core_version": "1.2.0",
        "bap_id": "buyerNP.com",
        "bap_uri": "https://buyerNP.com/ondc",
        "bpp_id": "sellerNP.com",
        "bpp_uri": "https://sellerNP.com/ondc",
        "transaction_id": "T2",
        "message_id": "M10",
        "timestamp": "2023-06-03T11:00:30.000Z",
        "ttl": "PT30S"
      },
      "message": {
        "order": {
          "id": order_number,
          "state": 'Cancelled',
          "tags": {
            "cancellation_reason_id": @cancellation_reason_id
          },
          "provider": {
            "id": "P#{@order.client_id}",
            "locations": [ #! How can we handle multiple locations
              {
                "id": "L#{@order.distribution_center_id}"
              }
            ]
          },
          'billing': {
            "name": @order.user_name,
            "address": @order.user_address,
            "email": @order.user_email,
            "phone": @order.user_phone,
            "created_at": @order.created_at,
            "updated_at": @order.updated_at
          },
          'quote': {
            "price": {
              "currency": @order.currency,
              "value": @order.amount
            },
            "breakup": @order.quote_breakup,
            'ttl': @order.ttl,  #! Static data
          },
          "cancellation": {
            "cancelled_by": "buyerNP.com", #! Giving Static not given in Confirm Params
            "reason": {
                "id": @cancellation_reason_id
            }
          },
          "payment": @order.ondc_order_payments.last.details, #! Taking last past payment details
          "created_at": @order.created_at,
          "updated_at": @order.updated_at,
          "items": [],
          "fulfillments": []
        }
      }
    }
  end

  def on_cancel
    begin
      ActiveRecord::Base.transaction do
        @order.update!(order_state: 'Cancelled', cancellation_reason_id: @cancellation_reason_id)
        
        create_order_history(@order.id, @order.order_state)
        
        @order_fulfillments.update_all(tracking: true)
        get_order_items
        get_fulfillments
        @payload_with_context[:message][:order][:fulfillments] << get_tags
        @payload_with_context
      end
    rescue => e
      raise e.backtrace
    end
  end

  def get_order_items
    @order.ondc_order_items.each do |order_item|
      @payload_with_context[:message][:order][:items] << {
        "id": "I#{order_item.inventory_id}",
        "fulfillment_id": order_item.fulfillment_number,
        "quantity": {
            "count": order_item.inventory.quantity
        }
      }
      @price_with_ids << "#{order_item.price}:#{order_item.inventory_id}"
      @payload_with_context[:message][:order][:items] << {
        "id": "I#{order_item.inventory_id}",
        "fulfillment_id": "C1",
        "quantity": {
            "count": order_item.quantity
        }
      }
    end
  end

  def get_fulfillments
    @order_fulfillments.each do |order_fulfillment|
      @payload_with_context[:message][:order][:fulfillments] << {
        "id": order_fulfillment.fulfillment_number,
        "@ondc/org/provider_name": @order.client.name,
        "state": { #! Giving Static
          "descriptor": {
            "code": "Pending" #! what is the reason for pending
          }
        },
        "type": order_fulfillment.fulfillment_type,
        "tracking": true,
        "@ondc/org/TAT": "PT60M", #! Giving Static
        "start": order_fulfillment.store_details,
        "end": order_fulfillment.customer_details,
        "tags": [ #! Staticlly Added
          {
            "code": "cancel_request",
            "list": [
              {
                "code": "reason_id",
                "value": "013"
              },
              {
                "code": "initiated_by",
                "value": "buyerNP.com"
              }
            ]
          },
          {
            "code": "igm_request",
            "list": [
              {
                "code": "id",
                "value": "Issue1"
              }
            ]
          },
          {
            "code": "precancel_state",
            "list": [
              {
                "code": "fulfillment_state",
                "value": "Order-picked-up"
              },
              {
                "code": "updated_at",
                "value": "2023-06-03T10:45:00.000Z"
              }
            ]
          }
        ]
      }
    end
  end

  def get_tags
    tags_data = { #! Staticly added
      "id": "C1",
      "type": "Cancel",
      "state": {
        "descriptor": {
          "code": "Cancelled"
        }
      },
      "tags": []
    }
    @price_with_ids.each do |price_with_id|
      price, id = price_with_id.split(':')
      tags_data[:tags] << [
        {
          "code": "quote_trail",
          "list": [
            {
                "code": "type",
                "value": "item"
            },
            {
                "code": "id",
                "value": "I#{id}"
            },
            {
                "code": "currency",
                "value": "INR"
            },
            {
                "code": "value",
                "value": "-#{price}"
            }
          ]
        }
      ]
    end
    tags_data
  end

end