class Api::V1::Warehouse::Wms::OutboundInventorySerializer < ActiveModel::Serializer

  attributes :tag_number, :serial_number, :sku_code, :ean, :grade, :serial_number_2, :source, :distribution_center_code


  def serial_number
    if object.serial_number.present?
      serial_number = object.serial_number.scan(/\D/).empty? ? "'" + object.serial_number :  object.serial_number
    else
      serial_number = ""
    end
  end

  def ean
    if object.details["ean"].present?
      ean = object.details["ean"].scan(/\D/).empty? ? "'" + object.details["ean"] :  object.details["ean"]
    else
      ean = ""
    end
  end

  def source
    object.details["source_code"]
  end

  def distribution_center_code
    object.distribution_center.code
  end

end
