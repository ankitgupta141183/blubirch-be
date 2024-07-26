class Api::V1::Warehouse::Wms::PackController < ApplicationController

  def fetch_orders
    set_pagination_params(params)
    status = LookupValue.where("code = ?", Rails.application.credentials.order_status_warehouse_pending_pack).first
    in_dispatch = LookupValue.where("code = ?", Rails.application.credentials.order_status_warehouse_in_dispatch).first
    partial_dispatch = LookupValue.where("code = ?", Rails.application.credentials.order_status_warehouse_partial_dispatch).first
    distribution_centers_ids = @current_user.distribution_centers.pluck(:id)
    if params.present?
      warehouse_order_ids = []
      lot_id = LiquidationOrder.where('lot_name LIKE ? OR id = ?', "%#{params['search']}%", params['search'].to_i).pluck(:id)
      wr_ids = WarehouseOrder.where(orderable_type: 'LiquidationOrder', orderable_id: lot_id).pluck(:id)
      ids = WarehouseOrder.where("lower(vendor_code) = ?", params['search']).pluck(:id)
      warehouse_order_ids.push(ids) if ids.present?
      warehouse_order_ids.push(wr_ids) if wr_ids.present?
      @warehouse_orders = WarehouseOrder.where(distribution_center_id: distribution_centers_ids, status_id: status.id, id: warehouse_order_ids.flatten.uniq).where.not(total_quantity: 0).order('updated_at desc').page(@current_page).per(@per_page)
    else
      @warehouse_orders = WarehouseOrder.where(distribution_center_id: distribution_centers_ids, status_id: status.id).where.not(total_quantity: 0).order('updated_at desc').page(@current_page).per(@per_page)
    end
    if @warehouse_orders.present?
      render json: @warehouse_orders, meta: pagination_meta(@warehouse_orders), statuses: {partial_dispatch_status: partial_dispatch.id, in_dispatch_status: in_dispatch.id}, warehouse_consignment_file_types: LookupKey.where(code: "WAREHOUSE_CONSIGNMENT_FILE_TYPES").last.lookup_values.pluck(:code, :original_code)
    else
      render json: {message: "Data not present", warehouse_orders: [], status: 302}
    end
  end

  def create_box
    @warehouse_order = WarehouseOrder.find(params['id'])
    distribution_center = @warehouse_order.distribution_center
    @packaging_box = PackagingBox.new(user: current_user, distribution_center: distribution_center)
    if @packaging_box.save
      render json: {box: @packaging_box}
    else
      render json: {message: "Box not created", status: 302}
    end
  end

  def remove_item
    @warehouse_order_item = WarehouseOrderItem.find(params['id'])
    if @warehouse_order_item.present?
      @warehouse_order_item.update_attributes(packaging_box_number: nil)
      render json: {message: "Item Removed", status: 200}
    else
      render json: {message: "Data not present", status: 302}
    end
  end

  def delete_box
    @packaging_box = PackagingBox.find(params['id'])
    if @packaging_box.present?
      order_items = WarehouseOrderItem.where(packaging_box_number: @packaging_box.box_number)
      order_items.update_all(packaging_box_number: nil) if order_items.present?
      @packaging_box.delete
      render json: {message: "Box successfully deleted", status: 200}
    else
      render json: {message: "Box not found", status: 302}
    end
  end

  def assign_box
    @warehouse_order_item = WarehouseOrderItem.find(params['id'])
    warehouse_order = @warehouse_order_item.warehouse_order
    distribution_center = warehouse_order.distribution_center
    box = PackagingBox.where(box_number: params['box_number']).first
    if !box.present?
      box = PackagingBox.new(user: current_user, distribution_center: distribution_center, box_number: params['box_number'])
      box.save
    end
    @warehouse_order_item.update_attributes(packaging_box_number: box.box_number)
    if warehouse_order.gatepass_number.blank?
      number = "G-#{SecureRandom.hex(3)}"
      gate_pass_status_created = LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_created).first
      @gatepass = GatePass.new(
        distribution_center_id: warehouse_order.distribution_center_id, 
        client_id: warehouse_order.client_id, 
        status_id: gate_pass_status_created.id, 
        user_id: current_user.id, 
        gatepass_number: number
      )
      if @gatepass.save
        warehouse_order.update_attributes(warehouse_gatepass_id: @gatepass.id, gatepass_number: @gatepass.gatepass_number)
      end
      render json: { warehouse_order_item: @warehouse_order_item, gatepass: @gatepass, packaging_box_id: box.id }
    else
      render json: { warehouse_order_item: @warehouse_order_item, packaging_box_id: box.id }
    end
  end

  def dispatch_confirm
    @warehouse_order = WarehouseOrder.where(id: params['id']).last
    status = LookupValue.where("code = ?", Rails.application.credentials.order_status_warehouse_pending_dispatch).first
    @warehouse_order.update_attributes(status_id: status.id)
    if @warehouse_order.details.nil?
      @warehouse_order.details = {"packed_by_user_id" => current_user.id, "packed_by_user_name" => current_user.full_name}
    else
      @warehouse_order.details["packed_by_user_id"] = current_user.id 
      @warehouse_order.details["packed_by_user_name"] = current_user.full_name
    end
    pending_dispatch_status = LookupValue.where("code = ?", Rails.application.credentials.order_status_warehouse_pending_dispatch).first
    @warehouse_order.warehouse_order_items.each do |warehouse_order_item|
      if @warehouse_order.orderable_type == "LiquidationOrder"
        item = warehouse_order_item.inventory.get_current_bucket
        if warehouse_order_item.packaging_box_number.present?
          original_code, status_id = LookupStatusService.new("Dispatch", "pending_dispatch").call
          item.update(status: original_code, status_id: status_id)
        else
          new_liquidation_status = LookupValue.find_by(code: 'liquidation_status_pending_liquidation')
          item.update(lot_name: "", liquidation_order_id: "" , status: new_liquidation_status.original_code , status_id: new_liquidation_status.id, is_active: true)
          if @warehouse_order.orderable.lot_type == 'Beam Lot'
            url =  Rails.application.credentials.beam_url+"/api/lots/delete_items"
            serializable_resource = {client_name:  "croma_online", tag_numbers: [item.tag_number]}.as_json
            RestClient::Request.execute(method: :post, url: url, payload: serializable_resource, verify_ssl: OpenSSL::SSL::VERIFY_NONE)
          end
        end
        details = { "#{item.status.try(:downcase).try(:strip).split(' ').join('_')}_created_at" => Time.now,
          "status_changed_by_user_id" => current_user.id,
          "status_changed_by_user_name" => current_user.full_name,
        }
        item.liquidation_histories.create(status_id: item.status_id, details: details)
      elsif @warehouse_order.orderable_type == "VendorReturnOrder"
        item = warehouse_order_item.inventory.get_current_bucket
        if warehouse_order_item.packaging_box_number.present?
          original_code, status_id = LookupStatusService.new("Dispatch", "pending_dispatch").call
          item.update(status: original_code, status_id: status_id)
        else
          vr_status = LookupValue.find_by_code(Rails.application.credentials.vendor_return_status_pending_dispatch)
          item.update(vendor_return_order_id: nil, status: vr_status.original_code, status_id: vr_status.id, is_active: true)
        end
        details = { "#{item.status.try(:downcase).try(:strip).split(' ').join('_')}_created_at" => Time.now,
          "status_changed_by_user_id" => current_user.id,
          "status_changed_by_user_name" => current_user.full_name,
        }
        item.vendor_return_histories.create(status_id: item.status_id, details: details)
      elsif @warehouse_order.orderable_type == "RedeployOrder"
        item = warehouse_order_item.inventory.get_current_bucket
        if warehouse_order_item.packaging_box_number.present?
          original_code, status_id = LookupStatusService.new("Dispatch", "pending_dispatch").call
          item.update(status: original_code, status_id: status_id)
        else
          rd_status = LookupValue.where("original_code = ?", "Pending Redeploy Destination").first
          item.update(redeploy_order_id: nil, status: rd_status.original_code, status_id: rd_status.id, is_active: true)
        end
        details = { "#{item.status.try(:downcase).try(:strip).split(' ').join('_')}_created_at" => Time.now,
          "status_changed_by_user_id" => current_user.id,
          "status_changed_by_user_name" => current_user.full_name,
        }
        item.redeploy_histories.create(status_id: item.status_id, details: details)
      end
      if warehouse_order_item.packaging_box_number.present?
        warehouse_order_item.toat_number = nil
        warehouse_order_item.status_id = pending_dispatch_status.id
        warehouse_order_item.status = pending_dispatch_status.original_code
        warehouse_order_item.save
      else
        @warehouse_order.update(total_quantity: @warehouse_order.total_quantity - 1)
        warehouse_order_item.delete
      end
    end
    render json: {message: "Packing Completed", status: 200}
  end

end