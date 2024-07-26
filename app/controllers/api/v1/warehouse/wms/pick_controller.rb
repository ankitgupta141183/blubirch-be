class Api::V1::Warehouse::Wms::PickController < ApplicationController

  def fetch_orders
    status_ids = []
    set_pagination_params(params)
    pending_dispatch = LookupValue.where("code = ?", Rails.application.credentials.order_status_warehouse_pending_dispatch).first
    in_dispatch = LookupValue.where("code = ?", Rails.application.credentials.order_status_warehouse_in_dispatch).first
    pending_pick = LookupValue.where("code = ?", Rails.application.credentials.order_status_warehouse_pending_pick).first
    partial_dispatch = LookupValue.where("code = ?", Rails.application.credentials.order_status_warehouse_partial_dispatch).first
    pending_pack = LookupValue.where("code = ?", Rails.application.credentials.order_status_warehouse_pending_pack).first
    status_ids << pending_pick.id << pending_pack.id
    if params[:dispatch].present?
      status_ids << pending_dispatch.id << in_dispatch.id
    end
    # status = LookupValue.where("code = ?", Rails.application.credentials.order_status_warehouse_pending_pick).first
    distribution_centers_ids = @distribution_center.present? ? [@distribution_center.id] : @current_user.distribution_centers.pluck(:id)
    if params['search'].present?
      warehouse_order_ids = []

      lot_id = LiquidationOrder.where('lot_name LIKE ? OR id = ?', "%#{params['search']}%", params['search'].to_i).pluck(:id)
      lot_id = RedeployOrder.where('lot_name LIKE ? OR id = ?', "%#{params['search']}%", params['search'].to_i).pluck(:id) if lot_id.blank?
      lot_id = VendorReturnOrder.where('lot_name LIKE ? OR id = ?', "%#{params['search']}%", params['search'].to_i).pluck(:id) if lot_id.blank?
      wr_ids = WarehouseOrder.where(orderable_type: ['LiquidationOrder', 'RedeployOrder', 'VendorReturnOrder'], orderable_id: lot_id).pluck(:id)
      ids = WarehouseOrder.where("lower(vendor_code) = ? ", params['search']).pluck(:id)
      vendor = VendorMaster.where("vendor_name LIKE ? ", "%#{params['search']}%").pluck(:vendor_code)
      vendor_ids = WarehouseOrder.where(vendor_code: vendor).pluck(:id)
      warehouse_order_ids.push(ids) if ids.present?
      warehouse_order_ids.push(wr_ids) if wr_ids.present?
      warehouse_order_ids.push(vendor_ids) if vendor_ids.present?
      @warehouse_orders = WarehouseOrder.includes(:warehouse_order_items, :distribution_center, :orderable).where(distribution_center_id: distribution_centers_ids, status_id: status_ids, id: warehouse_order_ids.flatten.uniq).where.not(total_quantity: 0).order('updated_at desc').page(@current_page).per(@per_page)
    else
      @warehouse_orders = WarehouseOrder.includes(:warehouse_order_items, :distribution_center, :orderable).where(distribution_center_id: distribution_centers_ids, status_id: status_ids).where.not(total_quantity: 0).order('updated_at desc').page(@current_page).per(@per_page)
    end
    if @warehouse_orders.present?
      render json: @warehouse_orders.includes(:warehouse_order_items), meta: pagination_meta(@warehouse_orders), statuses: {partial_dispatch_status: partial_dispatch.id, in_dispatch_status: in_dispatch.id}, warehouse_consignment_file_types: LookupKey.where(code: "WAREHOUSE_CONSIGNMENT_FILE_TYPES").last.lookup_values.pluck(:code, :original_code)
    else
      render json: {message: "Data not present", warehouse_orders: [], status: 302}
    end
  end

  def update_toat
    @warehouse_order_item = WarehouseOrderItem.find(params['id'])
    if params['toat_number'].present?
      @warehouse_order_item.update_attributes(toat_number: params['toat_number'])
      render json: { warehouse_order_item: @warehouse_order_item }
    end
  end

  def pick_confirm
    @warehouse_order = WarehouseOrder.where(id: params['id']).last
    if @warehouse_order.present?
      status = LookupValue.where("code = ?", Rails.application.credentials.order_status_warehouse_pending_pack).first
      @warehouse_order.update_attributes(status_id: status.id)
      if @warehouse_order.details.nil?
        @warehouse_order.details = {"picked_by_user_id" => current_user.id, "picked_by_user_name" => current_user.full_name}
      else
        @warehouse_order.details["picked_by_user_id"] = current_user.id 
        @warehouse_order.details["picked_by_user_name"] = current_user.full_name
      end
      @warehouse_order.save
      @warehouse_order.warehouse_order_items.each do |item|
        if item.toat_number.present?
          item.aisle_location =  nil
          item.status_id = status.id
          item.status = status.original_code
          item.save
        end
      end
      render json: {message: "Picking Completed", status: 200}
    else
      render json: {message: "Data not present", status: 302}
    end
  end

  def cancel_lot
    begin
      ActiveRecord::Base.transaction do
        warehouse_order = WarehouseOrder.find_by_id(params[:id])
        if warehouse_order.orderable_type == "LiquidationOrder"
          liquidation_order = warehouse_order.orderable
          @liquidation_item = liquidation_order.liquidations
          new_liquidation_status = LookupValue.find_by(code: 'liquidation_status_pending_liquidation')
          @liquidation_item.each do |liquidation|
            liquidation.update( lot_name: "", liquidation_order_id: "" , status: new_liquidation_status.original_code , status_id: new_liquidation_status.id, is_active: true)
            details = current_user.present? ? { status_changed_by_user_id: current_user.id, status_changed_by_user_name: current_user.full_name } : {}
            LiquidationHistory.create(
              liquidation_id: liquidation.id, status_id: new_liquidation_status.id, status: new_liquidation_status.original_code ,
              created_at: Time.now, updated_at: Time.now, details: details
          )
          end
          liquidation_order.details["deleted_by_user_id"] = current_user.id
          liquidation_order.details["deleted_by_user_name"] = current_user.full_name
          liquidation_order.save
          liquidation_order.delete
          if liquidation_order.lot_type == 'Beam Lot'
            url =  Rails.application.credentials.beam_url+"/api/lots/delete_items"
            serializable_resource = {client_name:  "croma_online", tag_numbers: liquidation_order.liquidations.pluck(:tag_number)}.as_json
            RestClient::Request.execute(method: :post, url: url, payload: serializable_resource, verify_ssl: OpenSSL::SSL::VERIFY_NONE)
          else
            BeamLotMailer.email_lot_cancel(liquidation_order.id).deliver_now if liquidation_order.lot_type == 'Email Lot'
          end
        elsif warehouse_order.orderable_type == "VendorReturnOrder"
          vendor_return_order = warehouse_order.orderable
          vendor_returns = vendor_return_order.vendor_returns
          vr_status = LookupValue.find_by_code(Rails.application.credentials.vendor_return_status_pending_dispatch)
          details = { "#{vr_status.original_code.try(:downcase).try(:strip).split(' ').join('_')}_created_at" => Time.now,
            "status_changed_by_user_id" => current_user.id,
            "status_changed_by_user_name" => current_user.full_name,
          }
          vendor_returns.each{|vr| vr.vendor_return_histories.create(status_id: vr_status.id, details: details)}
          vendor_returns.update_all(vendor_return_order_id: nil, status: vr_status.original_code, status_id: vr_status.id, is_active: true)
          vendor_return_order.delete
        elsif warehouse_order.orderable_type == "RedeployOrder"
          redeploy_order = warehouse_order.orderable
          redeploys = redeploy_order.redeploys
          rd_status = LookupValue.where("original_code = ?", "Pending Redeploy Destination").first
          details = { "#{rd_status.original_code.try(:downcase).try(:strip).split(' ').join('_')}_created_at" => Time.now,
            "status_changed_by_user_id" => current_user.id,
            "status_changed_by_user_name" => current_user.full_name,
          }
          redeploys.each{|rd| rd.redeploy_histories.create(status_id: rd_status.id, details: details)}
          redeploys.update_all(redeploy_order_id: nil, status: rd_status.original_code, status_id: rd_status.id, is_active: true)
          redeploy_order.delete
        end
        warehouse_order.warehouse_order_items.delete_all
        warehouse_order.delete
      end # transaction end
      render json: "success"
    rescue  Exception => message
      render json: { errors: message.to_s }, status: 500
    end
  end


  def edit_lot
    order = WarehouseOrder.find_by_id(params[:order_id])
    if order.present? && params[:files].present?
      params[:files].each do |document|
        document_key = LookupKey.where(code: "WAREHOUSE_ORDER_DOCUMENT_TYPES").last
        #document_type = document_key.lookup_values.where(code: document[1]["code"]).first
        attachment = order.warehouse_order_documents.new(document_name: "Manual Doc")
        attachment.attachment = document
        attachment.save(validate: false)
      end
      render json: "success"
    else
      render json: { errors: 'Record Not Found'}, status: 404
    end
  end


  def remove_item_from_lot
    warehouse_order_item = WarehouseOrderItem.find_by_id(params[:item_id])
    warehouse_order = warehouse_order_item.warehouse_order
    item = warehouse_order_item.inventory.get_current_bucket
    dispatch_status = LookupValue.where("code = ?", Rails.application.credentials.order_status_warehouse_dispatched).last
    begin
      ActiveRecord::Base.transaction do
        if warehouse_order.status_id != dispatch_status.id
          if warehouse_order.orderable_type == "LiquidationOrder"
            new_liquidation_status = LookupValue.find_by(code: 'liquidation_status_pending_liquidation')
            if warehouse_order.orderable.lot_type == 'Beam Lot'
              url =  Rails.application.credentials.beam_url+"/api/lots/delete_items"
              serializable_resource = {client_name:  "croma_online", tag_numbers: [item.tag_number]}.as_json
              RestClient::Request.execute(method: :post, url: url, payload: serializable_resource, verify_ssl: OpenSSL::SSL::VERIFY_NONE)
            end
            item.update(lot_name: "", liquidation_order_id: "" , status: new_liquidation_status.original_code , status_id: new_liquidation_status.id, is_active: true)
            LiquidationHistory.create(
              liquidation_id: item.id , 
              status_id: new_liquidation_status.try(:id), 
              status: new_liquidation_status.try(:original_code),
              details: {"status_changed_by_user_id" => current_user.id, "status_changed_by_user_name" => current_user.full_name } 
            )
          elsif warehouse_order.orderable_type == "VendorReturnOrder"
            vr_status = LookupValue.find_by_code(Rails.application.credentials.vendor_return_status_pending_dispatch)
            item.update(vendor_return_order_id: nil, status: vr_status.original_code, status_id: vr_status.id, is_active: true)
            details = { "#{vr_status.original_code.try(:downcase).try(:strip).split(' ').join('_')}_created_at" => Time.now,
              "status_changed_by_user_id" => current_user.id,
              "status_changed_by_user_name" => current_user.full_name,
            }
            item.vendor_return_histories.create(status_id: vr_status.id, details: details)
          elsif warehouse_order.orderable_type == "RedeployOrder"
            rd_status = LookupValue.where("original_code = ?", "Pending Redeploy Destination").first
            item.update(redeploy_order_id: nil, status: rd_status.original_code, status_id: rd_status.id, is_active: true)
            details = { "#{rd_status.original_code.try(:downcase).try(:strip).split(' ').join('_')}_created_at" => Time.now,
              "status_changed_by_user_id" => current_user.id,
              "status_changed_by_user_name" => current_user.full_name,
            }
            item.redeploy_histories.create(status_id: rd_status.id, details: details)
          end
          warehouse_order.update(total_quantity: warehouse_order.total_quantity - 1)
          warehouse_order_item.delete
          render json: "success"
        else
          render json: "status_error"
        end
      end
    rescue  Exception => message
      render json: { errors: message.to_s }, status: 500
    end
  end

  def adjust_amount
    order = LiquidationOrder.find_by_id(params[:id])
    if order.present?
      order.details['adjustment_reason'] = params['adjustment_reason']
      order.details['adjustment_amount'] = params['adjustment_amount']
      order.save
      render json: "success"
    else
      render json: { errors: 'Record Not Found'}, status: 404
    end
  end

end