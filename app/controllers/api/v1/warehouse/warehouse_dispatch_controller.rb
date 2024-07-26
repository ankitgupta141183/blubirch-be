class Api::V1::Warehouse::WarehouseDispatchController < ApplicationController

  def index
    set_pagination_params(params)
    lookup = LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_created).first
    @gate_passes = GatePass.filter(filtering_params).where(user_id: @current_user.id, status_id: lookup.id).order('updated_at desc').page(@current_page).per(@per_page)
    render json: @gate_passes, meta: pagination_meta(@gate_passes)
  end

  def get_selected_gate_passes
    @gate_passes = @current_user.gate_passes.where(id: params['ids'])
    if @gate_passes.present?
      render json: @gate_passes
    else
      render json: "Unable to get gate passes", status: :unprocessable_entity
    end
  end

  def logistics
    @logistics = LogisticsPartner.all
    render json: @logistics
  end

  def consignment_file_types
    @look_key = LookupKey.where(code: 'CONSIGNMET_FILE_TYPES').last
    @consignment_file_types = LookupValue.where(lookup_key_id: @look_key.id)
    render json: @consignment_file_types
  end

  def create_consignment
    params['consignment_files_attributes'] = []

    params.each do |k, v|
      if k == 'consignment_files_types'
        h = {}
        v.each_with_index do |type_id, i|
          h['consignment_file_type_id'] = type_id
          h['consignment_file'] = params["consignment_files"][i]
          params['consignment_files_attributes'].push(h)
        end
      end
    end

    @consignment = @current_user.consignments.new(consignment_params)
 
    if @consignment.save
      inventory_status_warehouse_closed_successfully = LookupValue.where(code: Rails.application.credentials.inventory_status_warehouse_closed_successfully).first
      gate_pass_status_in_transit = LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_in_transit).first
      params['gate_pass_ids'].each do |id|
        gate_pass = GatePass.find(id)
        gate_pass.update(status_id: gate_pass_status_in_transit.try(:id))
        ConsignmentGatePass.create(gate_pass: gate_pass, consignment: @consignment)
        inventories = Inventory.where("details ->> 'warehouse_gatepass_number' = ?", gate_pass.gatepass_number)
        inventories.each do |inventory|
          last_inventory_status = inventory.inventory_statuses.where(is_active: true).last
          new_inventory_status = last_inventory_status.dup
          new_inventory_status.status_id = inventory_status_warehouse_closed_successfully.try(:id)
          new_inventory_status.is_active = true
          if new_inventory_status.save
            last_inventory_status.update(is_active: false)
            inventory.update(details: inventory.merge_details({"packaging_status" => "Dispatch Complete", "rtv_status" => "Dispatch Complete"}))
          end
        end
      end
      render json: {message: 'Successfully Created Consignment'}
    else
      render json: "Unable to create Consignment", status: :unprocessable_entity
    end
  end

  private

  def filtering_params
    params.slice(:gatepass_number)
  end

  def consignment_params
    params.permit(:outward_document_number, :driver_name, :driver_contact_number, :truck_number, :logistics_partner_id, consignment_files_attributes: [:consignment_file_type_id, :consignment_file])
  end

end
