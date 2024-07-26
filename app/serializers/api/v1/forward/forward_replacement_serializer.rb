# frozen_string_literal: true

module Api
  module V1
    module Forward
      class ForwardReplacementSerializer < ActiveModel::Serializer
        include Utils::Formatting

        attributes :id, :tag_number, :distribution_center_id, :forward_inventory_id, :sku_code, :item_description, :reserve_id, :item_price, :selling_price, :payment_received, :reserved_date,
                   :payment_status, :location, :category, :brand, :quantity, :status

        def forward_inv
          object.forward_inventory
        end
        
        def reserved_date
          format_date(object.reserved_date)
        end

        def selling_price
          object.selling_price.to_f
        end

        def location
          object.distribution_center&.code
        end
        
        def category
          forward_inv&.client_category&.name
        end
        
        def brand
          forward_inv&.brand
        end
        
        def quantity
          1
        end
      end
    end
  end
end
