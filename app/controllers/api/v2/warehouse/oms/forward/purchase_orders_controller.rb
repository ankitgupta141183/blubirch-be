class Api::V2::Warehouse::Oms::Forward::PurchaseOrdersController < Api::V2::Warehouse::OrderManagementSystemsController
  OMS_TYPE = 'forward'
  ORDER_TYPE = 'purchase_order'
  ORDER_SERIALIZER = 'Api::V2::Warehouse::Oms::Forward::PurchaseOrdersSerializer'
  ORDER_ITEM_SERIALIZER = 'Api::V2::Warehouse::Oms::Forward::PurchaseOrderItemsSerializer'
  TALLY_SERVICE_PATH = 'Tally::InwardPurchaseOrderService'

  skip_before_action :authenticate_user!, :check_permission, only: :formatted_record

  #^ GET - /api/v2/warehouse/oms/forward/purchase_orders.json
  def index
    super
  end

  #^ POST - /api/v2/warehouse/oms/forward/purchase_orders.json
  def create
    super
  end

  #^ GET - /api/v2/warehouse/oms/forward/purchase_orders/15
  def show
    super
  end

  #^ GET - /api/v2/warehouse/oms/forward/purchase_orders/:id/items
  def items
    super
  end

  #^ GET - /api/v2/warehouse/oms/forward/purchase_orders/inventories_data?query=231581
  def inventories_data
    if params['query'].present?
      inventories = ClientSkuMaster.where(
        'code LIKE (?) OR sku_description LIKE (?)', "%#{params['query']}%", "%#{params['query']}%"
      ).select(:id, :code, :sku_description, :mrp).limit(10)
    end
    inventories = ClientSkuMaster.all.select(:id, :code, :sku_description, :mrp).limit(10) if params['query'].blank?
    render json: { inventories: inventories }
  end

  #^ GET - /api/v2/warehouse/oms/forward/purchase_orders/locations?query=Croma&selected_id=663
  def locations
    if params['query'].present?
      locations = DistributionCenter.includes(:city).where('name LIKE (?) ', "%#{params['query']}%")
    else
      locations = DistributionCenter.all
    end
    locations = locations.where.not(id: params['selected_id']) if params['selected_id'].present?
    locations = locations.limit(10).collect{|dc| {id: dc.id, name: dc.name, city: dc.city&.original_code} }
    render json: { locations: locations }
  end

  #^ GET - /api/v2/warehouse/oms/forward/purchase_orders/vendors?query=Arihant
  def vendors
    if params['query'].present?
      vendors = ClientProcurementVendor.where(
        'vendor_name LIKE (?) OR vendor_code LIKE (?)', "%#{params['query']}%", "%#{params['query']}%"
      ).select(:id, :vendor_name, :vendor_code, :vendor_type).limit(10)
    end
    vendors = ClientProcurementVendor.all.select(:id, :vendor_name, :vendor_code, :vendor_type).limit(10) if params['query'].blank?
    render json: { vendors: vendors }
  end

  #^ GET - /api/v2/warehouse/oms/forward/purchase_orders/tally_records?start_date=01-01-2024&end_date=08-01-2024
  def tally_records
    super
  end

  #^ GET - /api/v2/warehouse/oms/forward/purchase_orders/:id/detail
  def detail
    purchase_order = OrderManagementSystem.find_by(id: params[:id], oms_type: self.class::OMS_TYPE, order_type: self.class::ORDER_TYPE)
    raise 'No Record Found' if purchase_order.blank?
    
    record = {
      "creation_date" => purchase_order.created_at.to_s(:p_long),
      "purchase_price" => 0,
      "vendor_name" => purchase_order.vendor_details['vendor_name'],
      "items" => []
    }

    purchase_order_total_price = 0
    purchase_order.order_management_items.includes(:purchase_order_receipt_challans).each do |oms_item|
      item_quantity = oms_item.quantity.to_f
      rc_total_quantity = oms_item.purchase_order_receipt_challans.pluck(:quantity).compact.sum.to_f
      final_quantity = item_quantity - rc_total_quantity
      next if (final_quantity <= 0.0)
      total_price = oms_item.price.to_f *  final_quantity.to_f
      purchase_order_total_price = purchase_order_total_price.to_f + total_price.to_f
      record['items'] << {
        "id" => oms_item.id,
        "rc_number" => nil,
        "tag_number" => nil,
        "sku_code" => oms_item.sku_code,
        "item_description" => oms_item.item_description,
        "serial_number" => oms_item.serial_number,
        "quantity" => final_quantity,
        "value" => total_price,
        "status" => oms_item.status
      }
    end

    record['purchase_price'] = format_number(purchase_order_total_price)

    render json: { purchase_order: record }
  end

  private 

  def permitted_params
    params.require(:purchase_order).permit(:receiving_location_id, :billing_location_id, :vendor_id, :order_reason, :has_payment_terms, :remarks, :terms_and_conditions, items:[:sku_code, :item_description, :price, :quantity, :total_price], payment_term_details:{})
  end
end
