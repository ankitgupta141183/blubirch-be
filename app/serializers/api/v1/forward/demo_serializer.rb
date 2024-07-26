# frozen_string_literal: true

module Api
  module V1
    module Forward
      class DemoSerializer < ActiveModel::Serializer
        include Utils::Formatting

        attributes :id, :tag_number, :distribution_center_id, :forward_inventory_id, :sku_code, :item_description, :item_price, :location, :created_at

        def location
          object.distribution_center&.code
        end

        def created_at
          format_ist_time(object.created_at)
        end
      end
    end
  end
end
