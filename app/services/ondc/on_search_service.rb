class Ondc::OnSearchService < Ondc::BaseService

  #! Not Understood below part, it is for every location
  #! "creds": [
  #!   {
  #!       "id": "Auth33567",
  #!       "descriptor": {
  #!           "name": "Authorised Apple Dealer"
  #!       },
  #!       "url": "https://abcd.cdn.com/images/badge-img",
  #!       "tags": [
  #!           {
  #!               "code": "verification",
  #!               "list": [
  #!                   {
  #!                       "code": "verify_url",
  #!                       "value": "https://abcd.dnb.com/verify?id=’ESG-12345678'"
  #!                   },
  #!                   {
  #!                       "code": "valid_from",
  #!                       "value": "2023-06-03T00:00:00:000Z"
  #!                   },
  #!                   {
  #!                       "code": "valid_to",
  #!                       "value": "2024-06-03T23:59:59:999Z"
  #!                   }
  #!               ]
  #!           }
  #!       ]
  #!   }
  #! ]


  def initialize(from_date: (Date.current - 12.months).to_date, to_date: Date.current.to_date)
    @inventories = Inventory.includes(:distribution_center, :client_category).where("(DATE(created_at) BETWEEN ? AND ?) AND quantity > 1 and is_valid_inventory = true", from_date, to_date)
    @location_wise_items = {}
    raise "inventories blank" if @inventories.blank?
    @location_wise_items = @inventories.group_by(&:distribution_center_id)
    @location_based_on_ids = DistributionCenter.includes(:city, :state, :country).where(id: @inventories.pluck(:distribution_center_id)).select(:id, :name, :created_at, :city_id, :state_id, :address_line1, :address_line2, :address_line3, :address_line4, :country_id).group_by(&:id)
    @categories_based_on_ids = ClientCategory.where(id: @inventories.pluck(:client_category_id)).select(:id, :name).group_by(&:id)
    @lookup_value_based_id = LookupValue.all.select(:id, :original_code).group_by(&:id)
  end

  def full_catalog
    #! Issues -> 
    #! 1. No Connection between Client and DistributionCenters
    #! 2. We have 3 nested categories. how are we going to define here. 

    payload_with_static = {
      "context": {
          "domain": "ONDC:RET14",
          "country": "IND",
          "city": "std:080",
          "action": "on_search",
          "core_version": "1.2.0",
          "bap_id": "buyerNP.com",
          "bap_uri": "https://buyerNP.com/ondc",
          "bpp_id": "sellerNP.com",
          "bpp_uri": "https://sellerNP.com/ondc",
          "transaction_id": "T1",
          "message_id": "M1",
          "timestamp": "2023-06-03T08:00:30.000Z"
      },
      "message": { "catalog": {} }
    }

    #? Catalog -> bpp/fulfillments - Considering Static Delivery
    fulfillments = get_fulfillments_for_catalog

    #? Catalog -> bpp/descriptor - Client Information
    descriptor = get_descriptors_for_catalog

    #? Catalog -> bpp/providers
    providers = get_providers_for_catalog
    
    payload_with_static[:message][:catalog][:fulfillments] = fulfillments
    payload_with_static[:message][:catalog][:descriptor] = descriptor
    payload_with_static[:message][:catalog][:providers] = providers
    payload_with_static
  end

  def get_fulfillments_for_catalog
    { "bpp/fulfillments": [ { "id": 1, "type": "Delivery" } ] }
  end

  def get_descriptors_for_catalog
    client = Client.find_by_name("Croma") #! Taking Croma as a client
    descriptor = { 
      "bpp/descriptor": {
        "name": client.name,
        "symbol": "https://img.freepik.com/free-vector/bird-colorful-logo-gradient-vector_343694-1365.jpg", #! Static Image Url
        "short_desc": client.name, #! No Description for client
        "long_desc": client.name, #! No Description for client
        "images": ["https://img.freepik.com/free-vector/bird-colorful-logo-gradient-vector_343694-1365.jpg"]
      } 
    }
    descriptor
  end

  def get_providers_for_catalog
    providers = []
    @location_wise_items.each do |location_id, items_data|
      location = @location_based_on_ids[location_id]&.first
      next if location.blank?
      categories_data, tags_data = get_categories_for_catalog(items_data.pluck(:client_category_id).uniq, location_id)
      items_d = get_items_for_catalog(items_data)

      providers << {
        "id": "P#{location.id}",
        "time": {
          "label": "enable", #! Static
          "timestamp": location.created_at
        },
        "fulfillments": [
          {
            "contact": {
                "phone": "9324432946", #! Static
                "email": "gauravap@blubirch.com" #! Static
            }
          }
        ],
        "descriptor": {
          "name": location.name,
          "symbol": "https://img.freepik.com/free-vector/bird-colorful-logo-gradient-vector_343694-1365.jpg", #! Static
          "short_desc": location.name, #! Static
          "long_desc": location.name, #! Static
          "images": [
              "https://img.freepik.com/free-vector/bird-colorful-logo-gradient-vector_343694-1365.jpg" #! Static
          ]
        },
        "ttl": "P#{location.id}D", #! Not Understood
        "locations": [
          {
              "id": "L#{location.id}",
              "time": {
                  "label": "enable", #! Static
                  "timestamp": location.created_at,
                  "days": "1,2,3,4,5,6,7", #! Static
                  "schedule": { #! Static
                      "holidays": [
                          "2023-08-15"
                      ],
                      "frequency": "PT4H", #! Static
                      "times": [
                          "1100",
                          "1900"
                      ]
                  },
                  "range": { #! Static
                      "start": "1100",
                      "end": "2100"
                  }
              },
              "gps": "12.967555,77.749666", #! Static
              "address": {
                  "locality": location.address_line1,
                  "street": location.address_line2,
                  "city": (@lookup_value_based_id[location.city_id].first.original_code rescue 'Bengaluru'),
                  "area_code": "560076", #! Static
                  "state": (@lookup_value_based_id[location.state_id].first.original_code rescue 'KA') 
              },
              "circle": {
                  "gps": "12.967555,77.749666", #! Static
                  "radius": { #! Static
                      "unit": "km",
                      "value": "3"
                  }
              }
          }
        ],
        "categories": categories_data,
        "items": items_d,
        "tags": tags_data
      }
    end
    providers
  end

  def get_categories_for_catalog(category_ids, location_id)
    tags = []
    categories = []
    category_ids.each do |category_id|
      cat = @categories_based_on_ids[category_id]&.first
      next if cat.blank?
      categories << {
        "id": "CG#{cat.id}",
        "descriptor": {
          "name": cat.name
        },
        "tags": [ #! Static
          {
              "code": "type",
              "list": [
                  {
                      "code": "type",
                      "value": "custom_group"
                  }
              ]
          },
          {
              "code": "config",
              "list": [
                  {
                      "code": "min",
                      "value": "1"
                  },
                  {
                      "code": "max",
                      "value": "1"
                  },
                  {
                      "code": "input",
                      "value": "text"
                  },
                  {
                      "code": "seq",
                      "value": "1"
                  }
              ]
          }
        ]
      }
      tags << {
        "code": "serviceability",
        "list": [
            {
                "code": "location",
                "value": "L#{location_id}"
            },
            {
                "code": "category",
                "value": cat.name #! Static, when we want multiple categores. Based on arry we can add categories
            },
            {
                "code": "type", 
                "value": "12" #! Didn't understand
            },
            {
                "code": "val",
                "value": "IND"
            },
            {
                "code": "unit",
                "value": "country"
            }
          ]
      }
    end
    [categories, tags]
  end

  def get_items_for_catalog(items_data)
    items = []
    items_data.each do |inv|
      category = @categories_based_on_ids[inv.client_category_id]&.first
      next if category.blank?
      items << {
        "id": "I#{inv.id}",
        "time": {
          "label": inv.is_valid_inventory, 
          "timestamp": inv.created_at
        },
        "parent_item_id": "",
        "descriptor": {
            "name": inv.item_description, #! We Don't have name
            "code": inv.sku_code,
            "symbol": "https://sellerNP.com/images/i1.png", #! Dodn't find any column in Inventory
            "short_desc": inv.item_description,
            "long_desc": inv.item_description,
            "images": [
                "https://sellerNP.com/images/i1.png" #! Dodn't find any column in Inventory
            ]
        },
        "quantity": {
          "unitized": {
              "measure": {
                  "unit": "unit",
                  "value": "1" #! Static
              }
          },
          "available": {
              "count": inv.quantity
          },
          "maximum": {
              "count": inv.quantity
          }
        },
        "category_id": category.name,
        "fulfillment_id": "F1", #! Static
        "location_id": "L#{inv.distribution_center_id}",
        "@ondc/org/returnable": true, #! Static
        "@ondc/org/cancellable": true, #! Static
        "@ondc/org/return_window": "P7D", #! Static
        "@ondc/org/seller_pickup_return": true, #! Static
        "@ondc/org/time_to_ship": "PT3H", #! Static
        "@ondc/org/available_on_cod": false, #! Static
        "@ondc/org/contact_details_consumer_care": "Ramesh,ramesh@abc.com,18004254444", #! Static
        "@ondc/org/statutory_reqs_packaged_commodities": {
            "manufacturer_or_packer_name": (@location_based_on_ids[inv.distribution_center_id].first.name rescue ''),
            "manufacturer_or_packer_address": (@location_based_on_ids[inv.distribution_center_id].first.address rescue ''),
            "common_or_generic_name_of_commodity": "Mobile Phone", #! Static
            "month_year_of_manufacture_packing_import": "06/2023" #! Static
        },
        "tags": [
          {
              "code": "origin",
              "list": [
                  {
                      "code": "country",
                      "value": "IND"
                  }
              ]
          },
          {
              "code": "attribute",
              "list": inv.attributes.except("id").collect{|k,v| {"code" => k, "value" => v} if v.present? && k != "details" }.compact
          }
        ]
      }
    end
    items
  end

  #! This is Doubtfull
  def get_provider_tags_for_catalog()

  end

end