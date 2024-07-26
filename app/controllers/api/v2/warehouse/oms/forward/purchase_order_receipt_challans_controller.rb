class Api::V2::Warehouse::Oms::Forward::PurchaseOrderReceiptChallansController < Api::V2::Warehouse::Oms::Forward::PurchaseOrdersController

  before_action -> { set_pagination_params(params) }, only: [:index]
  before_action :get_rc_data, only: :index

  #^ GET - /api/v2/warehouse/oms/forward/purchase_order_receipt_challans
  def index
    @purchase_order_receipt_challans =  @purchase_order_receipt_challans.page(@current_page).per(@per_page)
    render_collection(@purchase_order_receipt_challans, Api::V2::Warehouse::Oms::Forward::PurchaseOrderReceiptChallansSerializer)
  end

  #^ POST - /api/v2/warehouse/oms/forward/purchase_order_receipt_challans
  def create 
    begin
      raise "Blank data" if permitted_params['items'].blank?
      rc_items = PurchaseOrderReceiptChallan.create_rc(oms_id: permitted_params['oms_id'], items: permitted_params['items'])
      render_success_message("Receipt Challan Created", 200)
    rescue => exe
      render_error("#{exe.message} -> #{exe.backtrace}", 422)
    end
  end

  #^ GET - /api/v2/warehouse/oms/forward/purchase_order_receipt_challans/details?rc_number=RC727602
  def details
    raise "RC number cannot be blank" if params['rc_number'].blank?
    purchase_order_receipt_challans = PurchaseOrderReceiptChallan.where(rc_number: params['rc_number'])

    oms = purchase_order_receipt_challans.first.oms
    creation_date = purchase_order_receipt_challans.first.created_at.to_s(:p_long)
    vendor_name = oms.vendor_details['vendor_name']

    final_hash = {
      "creation_date" => creation_date,
      "purchase_price" => purchase_order_receipt_challans.pluck(:total_price).compact.sum,
      "vendor_name" => vendor_name,
      "items" => []
    }

    purchase_order_receipt_challans.each do |po_challan|

      final_hash['items'] << {
        "tag_number" => po_challan.tag_number,
        "sku_code" => po_challan.sku_code,
        "item_description" => po_challan.item_description,
        "serial_number" => po_challan.serial_number,
        "quantity" => po_challan.quantity,
        "total_price" => po_challan.total_price,
        "status" =>  po_challan.status
      }
    end
    render json: { response: final_hash }
  end

  private 

  def permitted_params
    params.permit(:oms_id, items: [:id, :quantity])
  end

  def get_rc_data
    @purchase_order_receipt_challans = PurchaseOrderReceiptChallan.all
  end
  
end
