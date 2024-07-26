class Api::V1::Warehouse::LiquidationRequestSerializer < ActiveModel::Serializer
  attributes :id, :total_items, :graded_items, :status, :status_id, :request_id, :remaining_count, :color, :lot_created

  def remaining_count
    if object.graded_items > object.total_items
      0
    else
      object.total_items - object.graded_items
    end
  end

  def lot_created
    0
    # Commented as this is triggering query in the loop and this variable is not been used anywhere in frontend
    # object.liquidations.where.not(status: ['Pending Lot Creation', 'Pending Liquidation Regrade', 'Pending RFQ']).size
  end

  def color
    return 'red' if object.graded_items == 0
    return 'green' if object.graded_items == object.total_items
    return 'orange' if (object.graded_items != 0 && object.graded_items < object.total_items)
  end
end