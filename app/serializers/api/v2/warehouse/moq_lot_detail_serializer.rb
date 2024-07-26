class Api::V2::Warehouse::MoqLotDetailSerializer < ActiveModel::Serializer
  attributes :id, :lot_name, :lot_desc, :quantity, :mrp, :start_date, :end_date, :sub_lot_quantity

  def sub_lot_quantity
    object.details['sub_lot_quantity'].to_a
  end

  def start_date
    object.start_date_with_localtime
  end

  def end_date
    object.end_date_with_localtime
  end

  def mrp
    object.mrp
  end
end
