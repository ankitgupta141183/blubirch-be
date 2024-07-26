class Api::V2::Warehouse::Liquidation::ChannelAllocationsController < Api::V2::Warehouse::LiquidationsController
  STATUS = 'Pending Liquidation'

  before_action :check_for_e_waste_params, only: :mark_e_waste
  before_action :check_for_allocation_params, only: :allocate_channel
  before_action :set_liquidations, only: [:mark_e_waste, :allocate_channel]

  def mark_e_waste
    @liquidations.update_all(is_ewaste: params[:liquidation][:ewaste], updated_at: Time.current)
    action = params[:liquidation][:ewaste] == "Yes" ? "marked" : "unmarked"
    render_success_message("#{@liquidations.pluck(:tag_number).count} item(s) successfully #{action} as E-waste", :ok)
  end

  def allocate_channel
    is_ewaste_count = @liquidations.where("LOWER(is_ewaste) LIKE ?", 'yes').count
    if params[:liquidation][:alloted_channel] == 'liquidation_status_pending_b2c_publish' && is_ewaste_count > 0
      render_error('E-waste cannot be alloted to B2C', :unprocessable_entity) and return 
    else
      status = LookupValue.find_by(code: params[:liquidation][:alloted_channel])
      if params[:liquidation][:alloted_channel] == 'liquidation_status_pending_b2c_publish'
        message = "#{@liquidations.count} item(s) is successfully allocated to B2C (Price Discovery Method)"
      else
        message = "#{@liquidations.count} item(s) is successfully allocated to B2B (Price Discovery Method)"
      end
      update_liquidations_status(status: status.original_code, status_id: status.id, message: message)
    end
  end

  private

  def check_for_allocation_params
    render_error('Required params alloted_channel is missing!', :unprocessable_entity) and return if params[:liquidation][:alloted_channel].blank?

    render_error('Required params "liquidation_ids" is missing!', :unprocessable_entity) and return if params[:liquidation][:ids].blank?
    if params[:liquidation][:alloted_channel] == 'liquidation_status_pending_b2c_publish'
      params[:liquidation][:ids].each do |liquidation_id|
        liquidation = Liquidation.find(liquidation_id)
        render_error("Vendor Code is missing for #{liquidation.item_description}", :unprocessable_entity) and return if liquidation.vendor_code.blank?
        render_error("Client Category is not present for  #{liquidation.item_description}", :unprocessable_entity) and return if liquidation.client_category.blank?
        render_error("Seller Category is not present for  #{liquidation.item_description}", :unprocessable_entity) and return if liquidation.client_category.seller_category.blank?
        render_error("Bmaxx Category details mapping is not present for  #{liquidation.item_description}", :unprocessable_entity) and return if (liquidation.client_category.seller_category.details['bmaxx_child'].blank? || liquidation.client_category.seller_category.details['bmaxx_parent'].blank?)
      end
    end  
  end

  def check_for_e_waste_params

    render_error('Required params "e_waste" is missing!', :unprocessable_entity) and return if params[:liquidation][:ewaste].blank?

    render_error('Required params "liquidation_ids" is missing!', :unprocessable_entity) and return if params[:liquidation][:ids].blank?

    render_error('e_waste param will accept only these values Yes, No', :unprocessable_entity) and return unless ["Yes", "No"].include?(params[:liquidation][:ewaste])

  end
end
