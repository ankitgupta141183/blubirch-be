class Api::V1::Warehouse::PendingPackagingController < ApplicationController

  def index
    set_pagination_params(params)
    @inventories = Inventory.filter(filtering_params).where("details ->> 'packaging_status' = ?", 'Pending Package').order('updated_at desc').page(@current_page).per(@per_page)
    if @inventories.present?
      render json: @inventories, meta: pagination_meta(@inventories)
    else
      render json: "No Inventories Found", status: :unprocessable_entity
    end
  end

  def get_inventories
    @inventories = Inventory.where(id: params[:ids])
    if @inventories.present?
      render json: @inventories
    else
      render json: "No Inventories Found", status: :unprocessable_entity
    end
  end

  def create_box
    inventory =Inventory.find(params[:id])
    @packaging_box = PackagingBox.new(user: @current_user, distribution_center: inventory.distribution_center)
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

  def create_items
    gate_pass_status_created = LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_created).first
    packaging_boxes = []
    inventory_ids = []
    ActiveRecord::Base.transaction do
      @gate_pass = GatePass.new(gatepass_number: params["gate_pass"],user: @current_user, status_id: gate_pass_status_created.id, distribution_center_id: params["distribution_center_id"])
      if params[:boxes].present?
        params[:boxes].each do |box|
          packaging_box = PackagingBox.where("box_number = ?", box['box_number']).first
          if packaging_box.present?
            box['items'].each do |inventory|
              packaging_box.packed_inventories.create(inventory_id: inventory['inventory_id'])
              inventory_ids << inventory['inventory_id']
            end
            packaging_boxes << packaging_box
          end
        end
        @gate_pass.packaging_boxes << packaging_boxes

        if @gate_pass.save
          Inventory.where(id: inventory_ids).update_all("details = jsonb_set(details, '{packaging_status}', to_json('Pending Dispatch'::text)::jsonb)")
          Inventory.where(id: inventory_ids).each do |i|
            i.details['warehouse_gatepass_number'] = @gate_pass.gatepass_number
            i.save
          end
          @gate_pass.gate_pass_boxes.update_all(user_id: @current_user.id)
          render json: {gate_pass_number: @gate_pass.gatepass_number, boxes_count: @gate_pass.gate_pass_boxes.count, total_packed_inventory: (@gate_pass.packaging_boxes.collect(&:packed_inventories).flatten.size)}
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

  private
  def filtering_params
    params.slice(:tag_number)
  end

end