class Api::V1::Store::PendingPackagingController < ApplicationController

  def index
    set_pagination_params(params)
    approved_return_request = LookupValue.where("code = ?", Rails.application.credentials.return_request_pending_packaging).first
    if approved_return_request.present?
      @return_requests = ReturnRequest.filter(filtering_params).where(status_id: approved_return_request.try(:id)).order('updated_at desc').page(@current_page).per(@per_page)
      render json: @return_requests, meta: pagination_meta(@return_requests)
    else
      render json: "No Data Found", status: :unprocessable_entity
    end
  end

  def show
    @return_request = ReturnRequest.find_by(id: params[:id])
    if @return_request.present?
      render json: @return_request
    else
      render json: "No Record Found", status: :unprocessable_entity
    end
  end

  def add_packaging_box
    @return_request = ReturnRequest.find(params[:id])
    details = {return_request_number: @return_request.request_number}
    @packaging_box = PackagingBox.new(user: @current_user, distribution_center: @return_request.try(:distribution_center), details: details)
    if @packaging_box.save
      render json: @packaging_box
    else
      render json: "Unable to create box", status: :unprocessable_entity
    end
  end

  def generate_gate_pass

    string = "G-#{SecureRandom.hex(3)}"
    gate_pass = GatePass.where("gatepass_number = ?", string).first

    while gate_pass.present?
      string = "G-#{SecureRandom.hex(3)}"
      gate_pass = GatePass.where("gatepass_number = ?", string).first
    end

    render json: {gatepass_number: string}
  end

  def create_gatepass_items
    return_request = ReturnRequest.find(params[:id])
    return_request_inventories = Inventory.where("details ->> 'return_request_number' = ?", return_request.request_number)
    grading_required = return_request.customer_return_reason.grading_required
    gate_pass_status_created = LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_created).first
    packaging_boxes = []

    ActiveRecord::Base.transaction do
      @gate_pass = GatePass.new(gatepass_number: params["gate_pass"],user: @current_user, client: return_request.try(:client) ,distribution_center: return_request.try(:distribution_center), status_id: gate_pass_status_created.id)
      if params[:boxes].present?
        params[:boxes].each do |box|
          packaging_box = PackagingBox.where("box_number = ?", box['box_number']).first
          if packaging_box.present?
            if grading_required
              box['items'].each do |inventory|
                packaging_box.packed_inventories.create(inventory_id: inventory['inventory_id'])
              end
            end
            packaging_boxes << packaging_box
          end
        end
        @gate_pass.packaging_boxes << packaging_boxes

        if @gate_pass.save
          return_request_in_pending_dispatch = LookupValue.where("code = ?", Rails.application.credentials.return_request_pending_dispatch).first
          return_request.update(status_id: return_request_in_pending_dispatch.try(:id), details: return_request.merge_details({"gate_pass_creation_time" => Time.now.to_s}))
          inventories = Inventory.where("details ->> 'return_request_number' = ?", return_request.request_number)
          inventory_status_store_pending_store_dispatch = LookupValue.where("code = ?", Rails.application.credentials.inventory_status_store_pending_store_dispatch).first
          inventories.each do |inventory|
            last_inventory_status = inventory.inventory_statuses.where(is_active: true).last
            new_inventory_status = last_inventory_status.dup
            new_inventory_status.status_id = inventory_status_store_pending_store_dispatch.try(:id)
            new_inventory_status.is_active = true
            if new_inventory_status.save
              last_inventory_status.update(is_active: false)
              inventory.update(details: inventory.merge_details({"status" => inventory_status_store_pending_store_dispatch.try(:original_code), "gate_pass_number" => @gate_pass.gatepass_number}))
            end
          end
          @gate_pass.gate_pass_boxes.update_all(user_id: @current_user.id)
          render json: {gate_pass_number: @gate_pass.gatepass_number, boxes_count: @gate_pass.gate_pass_boxes.count, total_packed_inventory: (grading_required ? @gate_pass.packaging_boxes.collect(&:packed_inventories).flatten.size : return_request_inventories.size)}
        else
          render json: "Error in generating gate pass", status: :unprocessable_entity
        end
      end # End of box condition
    end #end of transsaction
  end

  def delete_packaging_box
    box = PackagingBox.find_by(id: params[:id])
    if box.present?
      box.delete
      render json: {message: 'Successfully Deleted'}
    else
      render json: "Unable to delete box", status: :unprocessable_entity
    end
  end

  def filtering_params
    params.slice(:request_number)
  end
end
