class Api::V1::Pos::DealerOrderInventoriesController < ApplicationController

  def get_dealer_order_inventory
    @dealer_order_inventories = DealerOrderInventory.filter(filtering_params).order('id desc')
    @dealer_order_inventories = @dealer_order_inventories.where(dealer_id: current_user.dealers.last.id, sale_status: "Available To Sell")
    render json: @dealer_order_inventories
  end

  private

    def filtering_params
      params.slice(:sku_master_code, :item_description)
    end
end
