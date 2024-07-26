# frozen_string_literal: true

module Api
  module V1
    module Forward
      class ProductionSerializer < ActiveModel::Serializer
        include Utils::Formatting

        attributes :id, :tag_number, :distribution_center_id, :forward_inventory_id, :sku_code, :item_description, :sku_type, :uom, :ageing, :toat_number

        def ageing
          (Date.current - object.inwarded_date).to_i rescue ""
        end

      end
    end
  end
end
