class Api::V1::Warehouse::GatePassesController < ApplicationController

  def fetch_gate_passes
    set_pagination_params(params)
    gate_pass_status_in_transit = LookupValue.where(code: Rails.application.credentials.gate_pass_status_in_transit).first
    @gate_passes = GatePass.where(status_id: gate_pass_status_in_transit.try(:id)).reorder(updated_at: :desc).page(@current_page).per(@per_page)
    render json: @gate_passes, meta: pagination_meta(@gate_passes)
  end

  def create_consignment_box
    params['consignment_box'] = JSON.parse(params['consignment_box']) rescue params['consignment_box']

    params['consignment_box']['consignment_box_files_attributes'] = []
    params.each do |k, v|
      if k == 'consignment_box_files_types'
        h = {}
        v.each_with_index do |type_id, i|
          h['consignment_box_file_type_id'] = type_id
          h['consignment_box_file'] = params["consignment_box_files"][i]
          params['consignment_box']['consignment_box_files_attributes'].push(h)
        end
      end
    end
    @consignment_box = ConsignmentBox.new(consignment_box_params)
    gate_pass = GatePass.where(gatepass_number: params[:gate_pass_number]).first
    gate_pass_status_received = LookupValue.where(code: Rails.application.credentials.gate_pass_status_received).first
    gate_pass_status_in_transit = LookupValue.where(code: Rails.application.credentials.gate_pass_status_in_transit).first
    @consignment_box.consignment_gate_pass_id = gate_pass.consignment_gate_pass.id
    ActiveRecord::Base.transaction do
      if gate_pass.status_id == gate_pass_status_in_transit.try(:id) && @consignment_box.save
        gate_pass.update(status_id: gate_pass_status_received.try(:id))
        @consignment_box.consignment_gate_pass.gate_pass.packaging_boxes.each do |box_detail|
          @consignment_box.box_details.create(details: {auth_id: "", awb_number: "", pslip_number: "", return_reason_id: "", box_number: box_detail.box_number})
        end
        render json: @consignment_box
      else
        render json: @consignment_box, status: :unprocessable_entity
      end
    end
  end

  def update_box_detail
    ActiveRecord::Base.transaction do
      consignment_box = ConsignmentBox.find(params[:consignment_box][:id])
      params[:consignment_box][:box_details].each do |box_detail|
        @box_detail = BoxDetail.find(box_detail[:id])
        @box_detail.update_attributes(details: box_detail[:details], box_condition_id: box_detail[:box_condition_id])
      end
      render json: consignment_box
    end
  end

  def complete_consignment
    gate_pass = GatePass.where(gatepass_number: params[:gate_pass_number]).first
    gate_pass_status_completed = LookupValue.where(code: Rails.application.credentials.gate_pass_status_completed).first
    gate_pass_status_received = LookupValue.where(code: Rails.application.credentials.gate_pass_status_received).first
    inventory_status_warehouse_pending_grade = LookupValue.where(code: Rails.application.credentials.inventory_status_warehouse_pending_grade).first
    if gate_pass.status_id == gate_pass_status_received.try(:id)
      gate_pass.update(status_id: gate_pass_status_completed.try(:id))
      inventories = Inventory.where("details ->> 'gate_pass_number' = ?", gate_pass.gatepass_number)
      inventories.each do |inventory|
        last_inventory_status = inventory.inventory_statuses.where(is_active: true).last
        new_inventory_status = last_inventory_status.dup
        new_inventory_status.status_id = inventory_status_warehouse_pending_grade.try(:id)
        new_inventory_status.distribution_center_id = distribution_center.try(:id)
        new_inventory_status.is_active = true
        if new_inventory_status.save
          last_inventory_status.update(is_active: false)
          inventory.update(distribution_center_id: distribution_center.try(:id), details: inventory.merge_details({"warehouse_inwarding_date" => Time.now.to_s, "store_distribution_center_id" => inventory.distribution_center_id, "status" => inventory_status_warehouse_pending_grade.try(:original_code)}))
        end
      end
      render json: gate_pass
    else
      render json: gate_pass, status: :unprocessable_entity
    end
  end

  def get_box_conditions
    @lookup_values = LookupKey.where(code: "WAREHOUSE_BOX_CONDITIONS").first.lookup_values
    render json: @lookup_values
  end

  def consignment_box_file_types
    @look_key = LookupKey.where(code: 'CONSIGNMET_BOX_FILE_TYPES').last
    @consignment_box_file_types = LookupValue.where(lookup_key_id: @look_key.id)
    render json: @consignment_box_file_types
  end

  def import
    @gate_passes = GatePass.import(params[:file], current_user)
    render json: @gate_passes, status: :created
  end

  private

  def consignment_box_params
    params.require(:consignment_box).permit(:consignment_gate_pass_id, :distribution_center_id, :box_count, :received_box_count, :delivery_date, :logistics_partner_id, consignment_box_files_attributes: [:consignment_box_file_type_id, :consignment_box_file])
  end

  def box_detail_params
    params.require(:box_detail).permit(:consignment_box_id, :box_condition_id, details: {})
  end

end