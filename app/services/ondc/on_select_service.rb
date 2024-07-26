class Ondc::OnSelectService < Ondc::BaseService

  def initialize(params_data)
    @order = params_data["message"]["order"]
    @payload_with_context = {
      "context": {
        "domain": "ONDC:RET10",
        "action": "on_select",
        "core_version": "1.2.0",
        "bap_id": "buyerNP.com",
        "bap_uri": "https://buyerNP.com/ondc",
        "bpp_id": "sellerNP.com",
        "bpp_uri": "https://sellerNP.com/ondc",
        "transaction_id": "T2",
        "message_id": "M2",
        "city": "std:080",
        "country": "IND",
        "timestamp": "2023-06-03T08:30:30.000Z"
      },
      'message': {
        'order': {
          'provider': { 'id': @order['provider']['id'] },
          'items': {},
          'fulfillments': [],
          'quote': {},
          'ttl': 'P1D'  #! Static data
        }
      }
    }

    @payload_order = @payload_with_context[:message][:order]


    #? message -> order -> provider
    raw_location_ids = @order['provider']['locations'].pluck('id')
    formatted_location_ids = raw_location_ids.each {|location| location.gsub!('L', '') }
    @locations = DistributionCenter.where(id: formatted_location_ids)

    @total_price = 0
    
    @items_id_with_rec = {}
    
    item_ids = @order['items'].pluck('id').each { |item_rec| item_rec.gsub!("I", "") }
    Inventory.where(id: item_ids).select(:id, :quantity, :item_price, :item_description).each { |inv| @items_id_with_rec[inv.id] = inv }
  end

  def get_selected_records
    #! Questions
    #! 1. if multiple items are not in stock. will the errors section will contain an array of errors?
    
    items_arr, items_error_data, items_breakup_details = get_items
    @payload_order[:items] = items_arr

    #? message -> order -> fulfilments
    
    @payload_order[:fulfillments] = get_fulfillments
    
    #? message -> order -> quote
    @payload_order[:quote] = {}
    
    #? message -> order -> quote -> price
    @payload_order[:quote][:price] = {  
      "currency": "INR", #! Static
      "value": @total_price
    }

    #? message -> order -> quote -> breakup
    @payload_order[:quote][:breakup] = items_breakup_details
    #! Not considering below breakup as we are not storing in db
    #! Delivery charges, Packing charges, Tax, Discount, Convenience Fee
    
    @payload_order[:ttl] = 'P1D' #! Adding Static

    @payload_order[:error] = items_error_data if items_error_data.present? #! DOUBTED. please check pt. 3 

    @payload_with_context
  end

  def get_items
    items_arr = []
    items_error_data = []
    items_breakup_details = []

    @order['items'].each do |items_data|
      item_record = @items_id_with_rec[items_data['id'].to_i]
      if item_record.present?
        items_arr << {
          "fulfillment_id": "F1", #! How we are sure when/how to send this!
          "id": "I#{items_data['id']}"
        }
        item_quantity = item_record.quantity 
        item_price = (item_quantity.to_f > 0 ? item_record.item_price : 0)
        @total_price = @total_price.to_f + item_price


        items_breakup_details << {
          "@ondc/org/item_id": "I#{items_data['id']}",
          "@ondc/org/item_quantity": {
              "count": item_record.quantity
          },
          "title": item_record.item_description, #! giving description instead of title
          "@ondc/org/title_type": "item",
          "price": {
              "currency": "INR", #! Static currency type
              "value": item_price.to_s
          },
          "item": {
            "quantity": {
                "available": {
                    "count": item_quantity.to_s
                },
                "maximum": {
                    "count": item_quantity.to_s
                }
            },
            "price": {
              "currency": "INR", #! Static currency
              "value": item_record.item_price
            }
          }
        }
        items_error_data << {
          "type": "DOMAIN-ERROR", #! Static
          "code": "40002", #! Static
          "message": "M1" #! Static
        } if item_quantity.to_f <= 0
      else
        raise"I#{items_data['id']}:item_not_present"
      end
    end
    [items_arr, items_error_data, items_breakup_details]
  end

  def get_fulfillments
    fulfillments = []
    @locations.each do |location|
      #! Search by gps can happen, seems we need to store gps in distribution_center

      fulfillments << {
        "id": "F1", #! How do we get this
        "@ondc/org/provider_name": location.name, #! Currently giving the name
        "tracking": false, #! Static, when this can be true
        "@ondc/org/category": "Immediate Delivery", #! Static
        "@ondc/org/TAT": "PT60M", #! Static
        "state": {
            "descriptor": {
                "code": "Serviceable" #! Giving Static
            }
        }
      }
    end
    fulfillments
  end
end