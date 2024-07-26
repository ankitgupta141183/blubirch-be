class Api::V2::DashboardController < ApplicationController

  def dashboard_embed_url
    account_id = Rails.application.credentials.aws_account_id
    is_inventory_present = Inventory.count > 0
    dashboard_id, is_data_present, preview_url = [Rails.application.credentials.quicksight_dashboard_id, is_inventory_present, Rails.application.credentials.quicksight_preview_image1]
    if params[:dashboard].present?
      if params[:dashboard].to_s == "2"
      dashboard_id, is_data_present, preview_url = [Rails.application.credentials.quicksight_dashboard_id2, is_inventory_present, Rails.application.credentials.quicksight_preview_image2]
      elsif params[:dashboard].to_s == "3"
        dashboard_id, is_data_present, preview_url =   [Rails.application.credentials.quicksight_dashboard_id3, is_inventory_present, '']
      elsif params[:dashboard].to_s == "4"
        dashboard_id, is_data_present, preview_url =   [Rails.application.credentials.quicksight_dashboard_id4, is_inventory_present, '']
      elsif params[:dashboard].to_s == "5"
        dashboard_id, is_data_present, preview_url =  [Rails.application.credentials.quicksight_dashboard_id5, is_inventory_present, '']
      elsif params[:dashboard].to_s == "6"
        dashboard_id, is_data_present, preview_url =  [Rails.application.credentials.quicksight_dashboard_id6, is_inventory_present, '']
      elsif params[:dashboard].to_s == "7"
        dashboard_id, is_data_present, preview_url =  [Rails.application.credentials.quicksight_dashboard_id7, is_inventory_present, '']
      end
    end
    user = Rails.application.credentials.aws_user
    region = Rails.application.credentials.aws_s3_region
    Aws.config.update({
      region: Rails.application.credentials.quicksight_access_region,
      credentials: Aws::Credentials.new(Rails.application.credentials.quicksight_access_key_id, Rails.application.credentials.quicksight_access_key)
    })
    # Create a QuickSight client
    client = Aws::QuickSight::Client.new(region: region)
    # Generate an embed URL for a QuickSight dashboard
    response = client.get_dashboard_embed_url({
      aws_account_id: account_id, 
      dashboard_id: dashboard_id, 
      session_lifetime_in_minutes: 100, 
      undo_redo_disabled: false, 
      reset_disabled: true, 
      user_arn: "arn:aws:quicksight:ap-south-1:#{account_id}:user/default/#{user}",
      # namespace: 'default',
      identity_type: 'QUICKSIGHT'
    })
    
    tiny_url = URI.encode(response.embed_url).to_s#.gsub("http", "https")
    preview_tiny_url = URI.encode(preview_url).to_s#.gsub("http", "https")
    
    render json: { embed_url: tiny_url, is_data_present: is_data_present, preview_url: preview_tiny_url}
  end

  def ai_discrepancy_reports
    set_pagination_params(params)
    inventory_grading_details = InventoryGradingDetail.all.order('updated_at desc').page(@current_page).per(@per_page)
    render_collection(inventory_grading_details, InventoryGradingDetailSerializer)
  end

  def ai_discrepancy_report
    inventory_grading_detail = InventoryGradingDetail.find(params[:id])
    render_resource(inventory_grading_detail, InventoryGradingDetailSerializer)
  end

end
