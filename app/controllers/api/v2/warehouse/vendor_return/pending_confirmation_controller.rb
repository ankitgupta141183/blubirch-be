class Api::V2::Warehouse::VendorReturn::PendingConfirmationController < Api::V2::Warehouse::VendorReturnsController
  STATUS = 'Pending Dispatch'

  before_action :check_for_return_detail_params, only: :update_confirmation
  before_action :set_vendor_returns, only: :update_confirmation

  def update_confirmation
    bucket_status =  LookupValue.find_by(code: Rails.application.credentials.vendor_return_status_pending_settlement)
    warehouse_order_status = LookupValue.find_by_code(Rails.application.credentials.order_status_warehouse_pending_pick)
    begin
      ActiveRecord::Base.transaction do
        @vendor_returns.each do |vendor_return|
          vendor_return.details ||= {}
          raise CustomErrors.new "Vendor is not present for tag_number #{vendor_return.tag_number}." if vendor_return.details&.dig('bcl_supplier').nil?
          vendor_return.details.merge!(return_detail_params)
          vendor_return.save
        end

        if (Date.today..7.days.from_now).include?(return_detail_params[:return_date].to_date)
          vendor_return_order = VendorReturnOrder.create!(lot_name: "9#{rand(1e8...1e9).to_i}", order_number: "OR-Brand-Call-Log-#{SecureRandom.hex(6)}")
          @vendor_returns.update_all(vendor_return_order_id: vendor_return_order.id, order_number: vendor_return_order.order_number, status_id: bucket_status.id, status: bucket_status.original_code)
          @vendor_returns.map{|vr|vr.inventory.update_inventory_status!(bucket_status)}

          warehouse_order = vendor_return_order.warehouse_orders.create!(distribution_center_id: @vendor_returns.first.distribution_center_id, vendor_code: vendor_return_order.vendor_code, reference_number: vendor_return_order.order_number, client_id: @vendor_returns.last.inventory.client_id, status_id: warehouse_order_status.id, total_quantity: vendor_return_order.vendor_returns.count)

          vendor_return_order.vendor_returns.each do |vr|
            client_category = ClientSkuMaster.find_by_code(vr.sku_code).client_category rescue nil

            warehouse_order.warehouse_order_items.create!(inventory_id: vr.inventory_id, aisle_location: vr.aisle_location, toat_number: vr.toat_number, client_category_id: client_category&.id, client_category_name:  client_category&.name, sku_master_code: vr.sku_code, item_description: vr.item_description, tag_number: vr.tag_number, quantity: 1, status_id: warehouse_order_status.id, status: warehouse_order_status.original_code, details: vr.inventory.details, serial_number: vr.inventory.serial_number)
          end
        else
          vendor_return_order = VendorReturnOrder.create!(lot_name: "9#{rand(1e8...1e9).to_i}", order_number: "OR-Brand-Call-Log-#{SecureRandom.hex(6)}")
          @vendor_returns.update_all(vendor_return_order_id: vendor_return_order.id, order_number: vendor_return_order.order_number)
        end
      end
    rescue StandardError => e
      return render_error(e.message, :unprocessable_entity)
    end
    render_success_message("Successfully updated!", :ok)
  end

  def brand_list
    brands = @vendor_returns.pluck(:details).map { |e| e.dig('brand') rescue nil }.uniq.compact.sort rescue []
    render json: { brand_list: brands }
  end

  def vendor_list
    suppliers = @vendor_returns.pluck(:details).map { |e| e.dig('bcl_supplier') rescue nil }.uniq.compact.sort rescue []
    render json: { vendor_list: suppliers }
  end

  private

  def check_for_return_detail_params
    return render_error('Required params vendor_return is missing!', :unprocessable_entity) if params[:vendor_return].blank?
    return render_error('Required params vendor_return_ids is missing!', :unprocessable_entity) if params[:vendor_return][:ids].blank?
  end

  def return_detail_params
    params.require(:vendor_return).permit(:return_date, :return_method, :return_document_type)
  end
end
