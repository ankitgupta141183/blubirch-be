class Api::V1::Warehouse::Wms::DispatchController < ApplicationController

  def index
    set_pagination_params(params)
    put_requests = current_user.put_requests.dispatch_requests.where(status: ["pending", "in_progress"]).order(updated_at: :desc)
    put_requests = put_requests.search_by_request_id(params[:search]) if params[:search].present?
    put_requests = put_requests.page(@current_page).per(@per_page)
    data = put_requests.map{ |put_request|
      {id: put_request.id, request_id: put_request.request_id, request_type: put_request.request_type&.titleize, status: put_request.status&.titleize}
    }
    
    render json: {put_requests: data, meta: pagination_meta(put_requests)}
  end

  def request_details
    @put_request = PutRequest.find_by(id: params[:id])
    data = {id: @put_request.id, request_id: @put_request.request_id, request_type: @put_request.request_type&.titleize, status: @put_request.status&.titleize, request_reason: @put_request.pick_up_reason&.titleize}
    data["items"] = @put_request.get_items_and_boxes
    
    render json: {put_request: data}
  end
  
  def fetch_orders
    status_ids = []
    set_pagination_params(params)
    pending_dispatch = LookupValue.where("code = ?", Rails.application.credentials.order_status_warehouse_pending_dispatch).first
    in_dispatch = LookupValue.where("code = ?", Rails.application.credentials.order_status_warehouse_in_dispatch).first
    partial_dispatch = LookupValue.where("code = ?", Rails.application.credentials.order_status_warehouse_partial_dispatch).first
    status_ids << pending_dispatch.id << in_dispatch.id << partial_dispatch.id
    distribution_centers_ids = @current_user.distribution_centers.pluck(:id)
    if params[:search].present?
      warehouse_order_ids = WarehouseOrderItem.where("lower(packaging_box_number) = ? OR lower(tag_number) = ? OR lower(serial_number) = ? OR packaging_box_number = ?", params['search'], params['search'], params['search'], (params['search'].split('_')[1])).pluck(:warehouse_order_id)
      ids = WarehouseOrder.where("lower(vendor_code) = ?", params['search']).pluck(:id)
      lot_id = LiquidationOrder.where('lot_name LIKE ? OR id = ?', "%#{params['search']}%", params['search'].to_i).pluck(:id)
      lot_id = RedeployOrder.where('lot_name LIKE ? OR id = ?', "%#{params['search']}%", params['search'].to_i).pluck(:id) if lot_id.blank?
      lot_id = VendorReturnOrder.where('lot_name LIKE ? OR id = ?', "%#{params['search']}%", params['search'].to_i).pluck(:id) if lot_id.blank?
      wr_ids = WarehouseOrder.where(orderable_type: ['LiquidationOrder', 'RedeployOrder', 'VendorReturnOrder'], orderable_id: lot_id).pluck(:id)
      vendor = VendorMaster.where("vendor_name LIKE ? ", "%#{params['search']}%").pluck(:vendor_code)
      vendor_ids = WarehouseOrder.where(vendor_code: vendor).pluck(:id)
      warehouse_order_ids.push(ids) if ids.present?
      warehouse_order_ids.push(wr_ids) if wr_ids.present?
      warehouse_order_ids.push(vendor_ids) if vendor_ids.present?
      @warehouse_orders = WarehouseOrder.includes(:warehouse_order_items, :distribution_center, :orderable).where(distribution_center_id: distribution_centers_ids, status_id: status_ids, id: warehouse_order_ids.flatten.uniq).where.not(total_quantity: 0).order('updated_at desc').page(@current_page).per(@per_page)
    else
      @warehouse_orders = WarehouseOrder.includes(:warehouse_order_items, :distribution_center, :orderable).where(distribution_center_id: distribution_centers_ids, status_id: status_ids).where.not(total_quantity: 0).order('updated_at desc').page(@current_page).per(@per_page)
    end
    doc_types = get_doc_types
    if @warehouse_orders.present?
      warehouse_orders = ActiveModel::SerializableResource.new(@warehouse_orders, each_serializer: Api::V1::Warehouse::Wms::WarehouseOrderSerializer, statuses: {partial_dispatch_status: partial_dispatch.id, in_dispatch_status: in_dispatch.id}, warehouse_consignment_file_types: LookupKey.where(code: "WAREHOUSE_CONSIGNMENT_FILE_TYPES").last.lookup_values.pluck(:code, :original_code)).as_json
      render :json => {
        warehouse_orders: warehouse_orders[:warehouse_orders],
        doc_types: doc_types,
        status: 200,
        meta: pagination_meta(@warehouse_orders)
      }
    else
      render json: {message: "Data not present", warehouse_orders: [], status: 302 }
    end
  end

  def dispatch_initiate
    param = JSON.parse(params["dispatch_initiate_data"])
    order = WarehouseOrder.includes(:warehouse_order_items).find(param['id'])
    status = LookupValue.where("code = ?", Rails.application.credentials.order_status_warehouse_in_dispatch).first
    if param["consignment_id"] == 0
      @warehouse_consignment = WarehouseConsignment.new(
                      transporter: param['transporter'],
                      truck_receipt_number: param['lorry_receipt_number'],
                      vehicle_number: param["vehicle_number"],
                      driver_name: param['driver_name'],
                      driver_contact_number: param['driver_contact_number']
                    )
      @warehouse_consignment.save
      
      order.update_attributes(delivery_reference_number: param["delivery_reference_number"], outward_invoice_number: param["invoice_number"],
       status_id: status.id, warehouse_consignment_id: @warehouse_consignment.id)
    else
      order.update_attributes(delivery_reference_number: param["delivery_reference_number"], outward_invoice_number: param["invoice_number"],
       status_id: status.id, warehouse_consignment_id: param["consignment_id"])
    end
    order.warehouse_order_items.update_all(status_id: status.id)
    order.details = {"dispatch_initiate_date" => Time.now.try(:to_datetime)}
    order.save

    params[:documents].each do |document|
      document_key = LookupKey.where(code: "WAREHOUSE_ORDER_DOCUMENT_TYPES").last
      document_type = document_key.lookup_values.where(code: document[1]["code"]).first
      attachment = order.warehouse_order_documents.new(reference_number: document[1]['reference_number'],
                                                   document_name: document_type.original_code,
                                                   document_name_id: document_type.id)
      attachment.attachment = document[1]['document']
      attachment.save
    end

    if @warehouse_consignment.present?
      render json: @warehouse_consignment
    else
      render json: {message: "Dispatch initiated successfully", consignment_id: param["consignment_id"], status: 200}
    end
  end

  def dispatch_initiate_new
    param = JSON.parse(params["dispatch_initiate_data"])
    status = LookupValue.where("code = ?", Rails.application.credentials.order_status_warehouse_in_dispatch).first
    pending_dispatch_status = LookupValue.where("code = ?", Rails.application.credentials.order_status_warehouse_pending_dispatch).first
    if param["consignment_id"] == 0
      @warehouse_consignment = WarehouseConsignment.new(
                      transporter: param['transporter'],
                      truck_receipt_number: param['lorry_receipt_number'],
                      vehicle_number: param["vehicle_number"],
                      driver_name: param['driver_name'],
                      driver_contact_number: param['driver_contact_number']
                    )
      @warehouse_consignment.save
      consignment_id = @warehouse_consignment.id
    else
      consignment_id = param["consignment_id"]
    end

    param["id"].each do |id|
      order = WarehouseOrder.find(id)
      order.update_attributes(delivery_reference_number: param["delivery_reference_number"], outward_invoice_number: param["invoice_number"],
       status_id: status.id, warehouse_consignment_id: consignment_id)
      
      # order.warehouse_order_items.update_all(status_id: status.id, status: status.original_code)
      
      order.warehouse_order_items.each do |item|
        if item.status_id = pending_dispatch_status.id
          item.status_id = status.id
          item.status = status.original_code
          item.save
        end
      end

      order.details = {"dispatch_initiate_date" => Time.now.try(:to_datetime)}
      order.save

      params[:documents].each do |document|
        document_key = LookupKey.where(code: "WAREHOUSE_ORDER_DOCUMENT_TYPES").last
        document_type = document_key.lookup_values.where(code: document[1]["code"]).first
        attachment = order.warehouse_order_documents.new(reference_number: document[1]['reference_number'],
                                                     document_name: document_type.original_code,
                                                     document_name_id: document_type.id)
        attachment.attachment = document[1]['document']
        attachment.save
      end
    end

    if @warehouse_consignment.present?
      render json: @warehouse_consignment
    else
      render json: {message: "Dispatch initiated successfully", consignment_id: param["consignment_id"], status: 200}
    end
  end

  def dispatch_complete
    begin
      ActiveRecord::Base.transaction do
        param = JSON.parse(params["dispatch_complete_data"])
        status = LookupValue.where("code = ?", Rails.application.credentials.order_status_warehouse_dispatched).first
        inventory_status_closed = LookupValue.where("code = ?", Rails.application.credentials.inventory_status_warehouse_closed_successfully).first
        pending_dispatch_status = LookupValue.where("code = ?", Rails.application.credentials.order_status_warehouse_pending_dispatch).first
        # pending_pick_status = LookupValue.where("code = ?", Rails.application.credentials.order_status_warehouse_pending_pick).first
        
        @warehouse_orders = WarehouseOrder.includes(orderable: [:liquidations, :redeploys, :e_wastes, :markdowns, :insurances], warehouse_order_items: :inventory).where(warehouse_consignment_id: param["consignment_id"])
        if @warehouse_orders.present?
          
          # @warehouse_orders.update_all(status_id: status.id)
      
          @warehouse_orders.each do |order|

            if order.warehouse_order_items.where(packaging_box_number: nil).present?
              # order.status_id = pending_pick_status.id
              # order.save
            else
              order.status_id = status.id
              order.details["dispatch_complete_date"] = Time.now.try(:to_datetime)
              order.details["dispatched_by_user_id"] = current_user.id 
              order.details["dispatched_by_user_name"] = current_user.full_name
              order.save
            end
            
            order.warehouse_order_items.each do |item|
              if item.status_id = pending_dispatch_status.id
                item.status_id = status.id
                item.status = status.original_code
                item.save
              end
            end

            if order.orderable_type == "LiquidationOrder"
              lot_status = LookupValue.where(code: Rails.application.credentials.lot_status_dispatched).last
              liquidation_order = LiquidationOrder.find(order.orderable_id)
              liquidation_order.status = lot_status.original_code
              liquidation_order.status_id = lot_status.id
              liquidation_order.save
              liquidation_order_history = LiquidationOrderHistory.create(liquidation_order_id:liquidation_order.id, status: lot_status.original_code, status_id: lot_status.id, details: {"Dispatched_created_date" => Time.now.to_s } ) 
              # close beam lot starts
              lot_type = LookupValue.find_by(code: Rails.application.credentials.liquidation_lot_type_beam_lot)
              if liquidation_order.lot_type_id == lot_type.id
                url =  Rails.application.credentials.beam_url+"/api/lots/close_lot"
                serializable_resource = {lot_name: liquidation_order.lot_name}.as_json
                # response = RestClient.post(url, serializable_resource, :verify_ssl => OpenSSL::SSL::VERIFY_NONE)
                response = RestClient::Request.execute(method: :post, url: url, payload: serializable_resource, verify_ssl: OpenSSL::SSL::VERIFY_NONE)
                parsed_response = JSON.parse(response)
                if parsed_response.present? && parsed_response["status"] == 500
                  raise ActiveRecord::Rollback
                end
              end
              dispatch_status = LookupValue.find_by_code(Rails.application.credentials.dispatch_status_completed)

              liquidations = order.orderable.liquidations

              liquidations.each do |record|
                record.update_attributes(status_id: dispatch_status.id, status: dispatch_status.original_code)
                details = { "#{dispatch_status.original_code.try(:downcase).try(:strip).split(' ').join('_')}_created_at" => Time.now,
                  "status_changed_by_user_id" => current_user.id,
                  "status_changed_by_user_name" => current_user.full_name,
                }
                record.liquidation_histories.create(status_id: dispatch_status.id, details: details)
              end
              # close beam lot ends
            end
            
            if order.orderable_type == "EWasteOrder"
              lot_status = LookupValue.where(code: Rails.application.credentials.lot_status_dispatched).last
              e_waste_order = EWasteOrder.find(order.orderable_id)
              e_waste_order.status = lot_status.original_code
              e_waste_order.status_id = lot_status.id
              e_waste_order.save
              e_waste_order_history = EWasteOrderHistory.create(e_waste_order_id:e_waste_order.id, status: lot_status.original_code, status_id: lot_status.id, details: {"Dispatched_created_date" => Time.now.to_s } ) 
            end

            if order.orderable_type == "VendorReturnOrder"
              dispatch_status = LookupValue.find_by_code(Rails.application.credentials.dispatch_status_completed)
              vr_status = LookupValue.where(code: Rails.application.credentials.vendor_return_status_pending_settlement).last

              vendor_returns = order.orderable.vendor_returns

              vendor_returns.each do |record|
                record.update_attributes(status_id: vr_status.id, status: vr_status.original_code)
                details = { "#{dispatch_status.original_code.try(:downcase).try(:strip).split(' ').join('_')}_created_at" => Time.now,
                  "status_changed_by_user_id" => current_user.id,
                  "status_changed_by_user_name" => current_user.full_name,
                }
                record.vendor_return_histories.create(status_id: dispatch_status.id, details: details)
                details = { "#{record.status.try(:downcase).try(:strip).split(' ').join('_')}_created_at" => Time.now,
                  "status_changed_by_user_id" => current_user.id,
                  "status_changed_by_user_name" => current_user.full_name,
                }
                record.vendor_return_histories.create(status_id: vr_status.id, details: details, created_at: 5.seconds.from_now)
              end
            end

            if order.orderable_type == "RedeployOrder"
              dispatch_status = LookupValue.find_by_code(Rails.application.credentials.dispatch_status_completed)

              redeploys = order.orderable.redeploys

              redeploys.each do |record|
                record.update_attributes(status_id: dispatch_status.id, status: dispatch_status.original_code)
                details = { "#{dispatch_status.original_code.try(:downcase).try(:strip).split(' ').join('_')}_created_at" => Time.now,
                  "status_changed_by_user_id" => current_user.id,
                  "status_changed_by_user_name" => current_user.full_name,
                }
                record.redeploy_histories.create(status_id: dispatch_status.id, details: details)
              end
            end

            # order.warehouse_order_items.update_all(status_id: status.id)

            order.update_bucket_status(order.orderable_type)

            if order.warehouse_order_items.present? && order.warehouse_order_items.collect(&:inventory_id).present?
              inventory_ids = order.warehouse_order_items.collect(&:inventory).flatten.collect(&:id)
              inventories = Inventory.where("id in (?)", inventory_ids)
              inventories.update_all(status_id: inventory_status_closed.id, status: inventory_status_closed.original_code)
              inventories.each do |inventory|
                inventory_status_active = inventory.inventory_statuses.where(is_active: true).try(:last)
                inventory.inventory_statuses.build(status_id: inventory_status_closed.id, user_id: current_user.id,
                                                   distribution_center_id: inventory.distribution_center_id, details: {"user_id" => current_user.id, "user_name" => current_user.username})
                inventory.status_id = inventory_status_closed.id
                inventory.status = inventory_status_closed.original_code
                inventory.details["dispatch_complete_date"] = Time.now.try(:to_datetime)
                if inventory.save
                  inventory_status_active.update(is_active: false) if inventory_status_active.present?
                end
              end
            end

          end
        
          # params[:documents].each do |document|
          #   document_key = LookupKey.where(code: "WAREHOUSE_ORDER_DOCUMENT_TYPES").last
          #   document_type = document_key.lookup_values.where(code: document[1]["code"]).first
          #   attachment = @warehouse_consignment.warehouse_order_documents.new(reference_number: document[1]['reference_number'],
          #                                                document_name: document_type.original_code,
          #                                                document_name_id: document_type.id)
          #   attachment.attachment = document[1]['document']
          #   attachment.save
          # end

          render json: {message: "Dispatched Successfully", status: 200}
        else
          render json: {message: "Data not present", status: 302}
        end
      end
    rescue
      render json: {message: "Server Error", status: 302}
    end
  end

  def update_pick_up_request
    ActiveRecord::Base.transaction do
      get_put_request

      get_sub_location
    
      update_put_request
    
      update_request_and_warehouse_item(tab_status: :pending_packaging, item_status: :pending_putaway)

      update_inventory

      render json: {message: "Picked Up Successfully"}
    end  
  end
  
  def update_putaway_item
    ActiveRecord::Base.transaction do
      get_put_request
      
      get_sub_location
      
      item = @put_request.request_items.find_by(id: params[:item_id])
      raise CustomErrors.new "Invalid Item Tag ID!" if item.blank?
      
      item.update!(to_sub_location_id: @sub_location.id, status: :completed)
      item.warehouse_order_item.update!(dispatch_request_status: :to_be_created, tab_status: :pending_packaging)
      item.inventory.update!(sub_location_id: @sub_location.id)
    
      pending_items = @put_request.request_items.where(status: [1,2])
      @put_request.update!(status: :completed, completed_at: Time.now) if pending_items.blank?
      
      render json: {}
    end
  end

  def add_box
    ActiveRecord::Base.transaction do
      raise CustomErrors.new "Please enter Toat ID!" if params[:box_no].blank?
      raise CustomErrors.new "Please select the items!" if params[:tag_numbers].blank?

      get_put_request
          
      update_put_request
      
      items = @put_request.request_items.joins(:inventory, :warehouse_order_item).where("inventories.tag_number IN (?)", params[:tag_numbers])
      destination = items.pluck(:"warehouse_order_items.destination").compact.uniq
      destination_type = items.pluck(:"warehouse_order_items.destination_type").compact.uniq
      raise CustomErrors.new "Destination should not be blank!" if (destination.blank? || destination_type.blank?)
      
      box = DispatchBox.find_or_initialize_by(status: :pending, box_number: params[:box_no])
      box.destination = destination[0]
      box.destination_type = destination_type[0]
      box.orrd = items.first.warehouse_order_item.orrd
      box.save!
      
      updated_items_count = 0
      items.each do |item|
        item.update!(box_no: params[:box_no], status: :completed)
        item.warehouse_order_item.update!(packaging_box_number: params[:box_no], dispatch_box_id: box.id)
        
        updated_items_count += 1
      end
      message = updated_items_count > 0 ? "#{updated_items_count} item(s) are added to the box" : "No Items were added to the box"

      render json: { message: message }
    end
  end
  
  def submit_pick_up_request
    ActiveRecord::Base.transaction do
      get_put_request
      raise CustomErrors.new "Request has to be for Pick Up" if !@put_request.request_type_pick_up?

      # not picked items are marked as "Not found"
      pending_pickup_items = @put_request.request_items.status_pending_pickup
      pending_pickup_items.each do |request_item|
        request_item.update!(status: :not_found)
        request_item.warehouse_order_item.update!(tab_status: :not_found_items)
      end
      
      @put_request.update!(status: "completed", completed_at: Time.now)
      
      bucket_status = LookupValue.where(code: "dispatch_status_pending_packaging").last
      @put_request.request_items.status_completed.each do |request_item|
        request_item.warehouse_order_item.inventory.update_inventory_status!(bucket_status, current_user.id)
      end

      render json: { message: "PickUp request #{@put_request.request_id} is successfully closed." }
    end
  end

  def submit_packaging_request
    ActiveRecord::Base.transaction do
      get_put_request
      raise CustomErrors.new "Request has to be for packaging" if !@put_request.request_type_packaging?
      pending_items = @put_request.request_items.where(status: [1,7])
      if pending_items.present?
        completed_items = @put_request.request_items.status_completed.count
        all_items = @put_request.request_items.count
        
        pending_items.each do |request_item|
          request_item.update!(status: :not_found)
          request_item.warehouse_order_item.update!(tab_status: :not_found_items)
        end
        message = "#{completed_items}/#{all_items} Tag/Box IDs successfully done with Packaging."
      end
      
      if !@put_request.status_completed?
        @put_request.request_items.status_completed.each do |item|
          params[:item_id] = item.id
          update_request_and_warehouse_item(tab_status: :pending_dispatch, item_status: :completed)
          
          bucket_status = LookupValue.where(code: "dispatch_status_pending_dispatch").last
          item.warehouse_order_item.inventory.update_inventory_status!(bucket_status, current_user.id)
        end
        @put_request.update!(status: :completed, completed_at: Time.now)
      end
      message = "Packaging Request #{@put_request.request_id} is successfully closed." if message.blank?
      
      render json: { message: message }
    end
  end
  
  def pending_dispatch
    set_pagination_params(params)
    dispatch_boxes = DispatchBox.status_pending.order("id desc")
    dispatch_boxes = dispatch_boxes.where(destination: params[:box_number]) if params[:box_number].present?
    grouped_data = dispatch_boxes.select(:destination_type, :destination, :id).group(:destination_type, :destination).pluck(:destination_type, :destination, 'MAX(id) AS id')
    grouped_data = Kaminari.paginate_array(grouped_data).page(@current_page).per(@per_page)
    data = grouped_data.map{|i| {destination_type: i[0], destination: i[1]} }
    
    render json: {dispatch_data: data, meta: pagination_meta(grouped_data)}
  end

  def destination_based_boxes
    raise CustomErrors.new "Destination can't be blank" if params[:destination].blank?

    set_pagination_params(params)
    dispatch_boxes = DispatchBox.where(status: :pending, destination: params[:destination])
    grouped_data = dispatch_boxes.as_json(only: [:id, :destination_type, :destination, :box_number, :orrd], methods: [:tag_numbers, :or_document])

    render json: {dispatch_data: grouped_data}
  end

  def update_dispatch_details
    ActiveRecord::Base.transaction do
      dispatch_boxes = DispatchBox.where(id: JSON.parse(params[:ids]))
      raise CustomErrors.new "Invalid ID!" if dispatch_boxes.blank?
      
      params[:outward_reference_value] = JSON.parse(params[:outward_reference_value]) if params[:outward_reference_value].present?
      params[:cancelled_items] = JSON.parse(params[:cancelled_items]) if params[:cancelled_items].present?
      
      dispatch_boxes.validate_dispatch_details(params)
      
      dispatch_boxes.each do |dispatch_box|
        dispatch_box.update_dispatch_details(params)
      end
      
      render json: {message: "Dispatch details updated successfully"}
    end
  end

  def close_beam_lot
    begin
      ActiveRecord::Base.transaction do
        param = JSON.parse(params["dispatch_complete_data"])
        status = LookupValue.where("code = ?", Rails.application.credentials.order_status_warehouse_dispatched).first
        inventory_status_closed = LookupValue.where("code = ?", Rails.application.credentials.inventory_status_warehouse_closed_successfully).first
        @warehouse_consignment = WarehouseConsignment.find(param["consignment_id"])
        @warehouse_orders = WarehouseOrder.includes(warehouse_order_items: :inventory).where(warehouse_consignment_id: param["consignment_id"])
        if @warehouse_orders.present?
          @warehouse_orders.update_all(status_id: status.id)
      
          @warehouse_orders.each do |order|      
            order.details["dispatch_complete_date"] = Time.now.try(:to_datetime)
            order.save

            if order.orderable_type == "LiquidationOrder"
              lot_status = LookupValue.where(code: Rails.application.credentials.lot_status_dispatched).last
              liquidation_order = LiquidationOrder.find(order.orderable_id)
              liquidation_order.status = lot_status.original_code
              liquidation_order.status_id = lot_status.id
              liquidation_order.save
              liquidation_order_history = LiquidationOrderHistory.create(liquidation_order_id:liquidation_order.id, status: lot_status.original_code, status_id: lot_status.id, details: {"Dispatched_created_date" => Time.now.to_s } ) 
              # close beam lot starts
              lot_type = LookupValue.find_by(code: Rails.application.credentials.liquidation_lot_type_beam_lot)
              if liquidation_order.lot_type_id == lot_type.id
                url =  Rails.application.credentials.beam_url+"/api/lots/close_lot"
                serializable_resource = {lot_name: liquidation_order.lot_name}.as_json
                # response = RestClient.post(url, serializable_resource, :verify_ssl => OpenSSL::SSL::VERIFY_NONE)
                response = RestClient::Request.execute(method: :post, url: url, payload: serializable_resource, verify_ssl: OpenSSL::SSL::VERIFY_NONE)
              end
              # close beam lot ends
            end
            
            if order.orderable_type == "EWasteOrder"
              lot_status = LookupValue.where(code: Rails.application.credentials.lot_status_dispatched).last
              e_waste_order = EWasteOrder.find(order.orderable_id)
              e_waste_order.status = lot_status.original_code
              e_waste_order.status_id = lot_status.id
              e_waste_order.save
              e_waste_order_history = EWasteOrderHistory.create(e_waste_order_id:e_waste_order.id, status: lot_status.original_code, status_id: lot_status.id, details: {"Dispatched_created_date" => Time.now.to_s } ) 
            end

            if order.orderable_type == "VendorReturnOrder"
              
              status = LookupValue.where(code: Rails.application.credentials.vendor_return_status_pending_settlement).last
              vendor_returns = order.orderable.vendor_returns
              
              vendor_returns.each do |record|
                record.update_attributes(status_id: status.id, status: status.original_code)
                vrh = record.vendor_return_histories.new(status_id: record.status_id)
                vrh.details = {}
                key = "#{record.status.try(:downcase).try(:strip).split(' ').join('_')}_created_at"
                vrh.details[key] = Time.now
                vrh.save
              end
            end

            order.warehouse_order_items.update_all(status_id: status.id)

            order.update_bucket_status(order.orderable_type)

            if order.warehouse_order_items.present? && order.warehouse_order_items.collect(&:inventory_id).present?
              inventory_ids = order.warehouse_order_items.collect(&:inventory).flatten.collect(&:id)
              inventories = Inventory.where("id in (?)", inventory_ids)
              inventories.update_all(status_id: inventory_status_closed.id, status: inventory_status_closed.original_code)
              inventories.each do |inventory|
                inventory_status_active = inventory.inventory_statuses.where(is_active: true).try(:last)
                inventory.inventory_statuses.build(status_id: inventory_status_closed.id, user_id: current_user.id,
                                                   distribution_center_id: inventory.distribution_center_id, details: {"user_id" => current_user.id, "user_name" => current_user.username})
                inventory.status_id = inventory_status_closed.id
                inventory.status = inventory_status_closed.original_code
                inventory.details["dispatch_complete_date"] = Time.now.try(:to_datetime)
                if inventory.save
                  inventory_status_active.update(is_active: false) if inventory_status_active.present?
                end
              end
            end

          end
        
          params[:documents].each do |document|
            document_key = LookupKey.where(code: "WAREHOUSE_ORDER_DOCUMENT_TYPES").last
            document_type = document_key.lookup_values.where(code: document[1]["code"]).first
            attachment = @warehouse_consignment.warehouse_order_documents.new(reference_number: document[1]['reference_number'],
                                                         document_name: document_type.original_code,
                                                         document_name_id: document_type.id)
            attachment.attachment = document[1]['document']
            attachment.save
          end

          render json: {message: "Dispatched Successfully", status: 200}
        else
          render json: {message: "Data not present", status: 302}
        end
      end
    rescue
      render json: {message: "Server Error", status: 302}
    end
  end

  private

  def get_doc_types
    warehouse_document_types = []
    rtn_file_code =  ["E-Way Bill", "LR", "NRGP", "GI", "RTN"]
    tax_invoice_file_code =  ["Invoice", "E-Way Bill", "LR", "NRGP"]
    liquidation_file_code =  ["Invoice", "E-Way Bill", "NRGP"]
    store_file_code =  ["STO", "E-Way Bill", "NRGP"]
    dc_file_code =  ["STO", "E-Way Bill", "NRGP"]
    rpa_file_code =  ["STO", "E-Way Bill", "NRGP"]
    
    file_type_lookup_key = LookupKey.where(code: "WAREHOUSE_ORDER_DOCUMENT_TYPES").last rescue ""
    file_type_array = ["RTN for Vendor Returns", "Tax Invoice For Vendor Returns", "Tax Invoice For Liquidation", 
      "Store Re-Deployment", "DC Re-Deployment", "RPA to RPA movement"]

    file_type_array.each do |file_type_key|
      file_type_data = {}
      codes = []
      types = []
      case file_type_key
        when "RTN for Vendor Returns"
          codes = rtn_file_code
        when "Tax Invoice For Vendor Returns"
          codes = tax_invoice_file_code
        when "Tax Invoice For Liquidation"
          codes = liquidation_file_code
        when "Store Re-Deployment"
          codes = store_file_code
        when "DC Re-Deployment"
          codes = dc_file_code
        when "RPA to RPA movement"
          codes = rpa_file_code
        end
      file_type_lookup_key.lookup_values.where(original_code: codes).each do |lookup_val|
        file_types = {}
        file_types["original_code"] = lookup_val.original_code
        file_types["code"] = lookup_val.code
        file_types["required"] = lookup_val.original_code == "E-Way Bill" ? false : true
        types << file_types
      end
      file_type_data[file_type_key] = types
      warehouse_document_types << file_type_data
    end
    return warehouse_document_types

  end

  def get_put_request
    @put_request = PutRequest.find_by(id: params[:id])
  end

  def get_sub_location
    @distribution_center = @put_request.distribution_center
    @sub_location = @distribution_center.sub_locations.find_by(code: params[:location_code])
    raise CustomErrors.new "Invalid Location Code!" if @sub_location.blank?
  end

  def update_put_request
    @put_request.update!(status: :in_progress) if @put_request.status_pending?
  end

  def update_request_and_warehouse_item(tab_status: , item_status: )
    @item = @put_request.request_items.find_by(id: params[:item_id])
    raise CustomErrors.new "Invalid Item Tag ID!" if @item.blank?
      
    @item.update!(status: item_status)

    @item.warehouse_order_item.update!(dispatch_request_status: :to_be_created, tab_status: tab_status) if item_status == :completed
  end

  def update_inventory
    @inventory = @item.inventory
    @inventory.update!(sub_location_id: nil)
  end

  def create_box
    
  end

end