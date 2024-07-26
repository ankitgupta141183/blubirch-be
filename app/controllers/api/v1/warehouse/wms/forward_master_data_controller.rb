class Api::V1::Warehouse::Wms::ForwardMasterDataController < ApplicationController
  
  before_action :permit_param
  skip_before_action :check_permission
  skip_before_action :authenticate_user!, only: [:forward_import_document, :master_skus, :vendor_masters, :distribution_centers, :import_gi_document, :doc_error_response, :import_pkslip, :exp_articles_scan_ind_mapping, :exp_articles_sr_no_length_mapping, :import_rtn_document]
  before_action :render_message, unless: :check_header, except: [:doc_error_response, :export_inbound_documents, :export_outbound_documents, :exp_articles_file_upload, :list_expectional_articles, :list_expectional_article_serial_number]

  def import_gi_document
    master_data = MasterDataInput.create(payload: params.except(:forward_master_datum, :controller, :action), master_data_type: 'GatePass', status: "Initiated")
    if master_data.save
      MasterDataCreateWorker.perform_async(master_data.id, 'GI')
      success_json(master_data)
    else
      render json: "Error in creating API Request", status: 422
    end
  end

  def forward_import_document
    master_data = MasterDataInput.new(payload: params.except(:forward_master_datum, :controller, :action), master_data_type: 'GatePass', status: "Initiated")
    if master_data.save
      MasterDataCreateWorker.perform_async(master_data.id, 'GatePass')
      success_json(master_data)
    else
      error_json(master_data)
    end
  end

  def import_pkslip
    master_data = MasterDataInput.create(payload: params.except(:forward_master_datum, :controller, :action), master_data_type: 'OutboundDocument', status: "Initiated")
    if master_data.save
      MasterDataCreateWorker.perform_async(master_data.id, 'OutboundDocument')
      success_json(master_data)
    else
      render json: "Error in creating API Request", status: 422
    end
  end

  def import_rtn_document
    master_data = MasterDataInput.create(payload: params.except(:forward_master_datum, :controller, :action), master_data_type: 'OutboundRTNDocument', status: "Initiated")
    if master_data.save
      MasterDataCreateWorker.perform_async(master_data.id, 'OutboundRTNDocument')
      success_json(master_data)
    else
      render json: "Error in creating API Request", status: 422
    end
  end

  def master_skus
    master_data = MasterDataInput.create(payload: params[:payload], master_data_type: 'SKU', status: "Initiated")
    if master_data.save
      MasterDataCreateWorker.perform_async(master_data.id, 'SKU')
      success_json(master_data)
    else
      error_json(master_data)
    end
  end

  def vendor_masters
    master_data = MasterDataInput.create(payload: params[:payload], master_data_type: 'Vendor', status: "Initiated")
    if master_data.save
      MasterDataCreateWorker.perform_async(master_data.id, 'Vendor')
      success_json(master_data)
    else
      error_json(master_data)
    end
  end

  def distribution_centers
    master_data = MasterDataInput.create(payload: params[:payload], master_data_type: 'DC', status: "Initiated")
    if master_data.save
      MasterDataCreateWorker.perform_async(master_data.id, 'DC')
      success_json(master_data)
    else
      error_json(master_data)
    end
  end

  def doc_error_response
    begin
      master_data_input = MasterDataInput.where("id = ?", params[:master_data_input_id]).first 
      if master_data_input.present?
        headers = {"IntegrationType" => "INBDERROR", "Ocp-Apim-Subscription-Key" => Rails.application.credentials.sap_subscription_key }
        response = RestClient::Request.execute(:method => :post, :url => Rails.application.credentials.inbound_sap_error_apim_end_point, :payload => params[:errors_hash].to_json, :timeout => 9000000, :headers => headers)
        parsed_response = JSON.parse(response)      
        master_data_input.update(is_response_pushed: true) if parsed_response["status"] == "SUCCESS"
      end
    rescue
      Rails.logger.warn("------- Error in updating response of master data input id #{params[:master_data_input_id]}")
    end
  end

  def export_inbound_documents
    # type = "inbound_documents"
    # report = ReportStatus.where(distribution_center_ids: current_user.distribution_centers.pluck(:id), report_type: 'inbound_documents', created_at: (Time.zone.now - 1.hour)..(Time.zone.now), status: 'Completed').last
    # if report.present?
    #   #Send Mail with URL
    #   url = report.details['url']
    #   timestamp = report.details['completed_at_time']
    #   ReportMailer.inbound_documents_email("" ,url, current_user.id, current_user.email, timestamp).deliver_now
    #   render json: 'Success', status: 200
    # elsif !get_report_status(type)
      InboundReportMailerWorker.perform_async("inbound_documents", @current_user.id, params[:start_date], params[:end_date], params[:dc_inbound_receiving_site], params[:dc_inbound_supplying_site])
      render json: 'Success', status: 200
    # else
    #   render json: {message: "Inward Report Already In Process and will be sent to email #{current_user.email} Shortly", status: 302}
    # end
  end

  def export_outbound_documents
    # type = "outbound_documents"
    # report = ReportStatus.where(distribution_center_ids: current_user.distribution_centers.pluck(:id), report_type: 'outbound_documents', created_at: (Time.zone.now - 1.hour)..(Time.zone.now), status: 'Completed').last
    # if report.present?
    #   #Send Mail with URL
    #   url = report.details['url']
    #   timestamp = report.details['completed_at_time']
    #   ReportMailer.outbound_documents_email("" ,url, current_user.id, current_user.email, timestamp).deliver_now
    #   render json: 'Success', status: 200
    # elsif !get_report_status(type)
      OutboundReportMailerWorker.perform_async("outbound_documents", @current_user.id, params[:start_date], params[:end_date], params[:dc_outbound_receiving_site], params[:dc_outbound_supplying_site])
      render json: 'Success', status: 200
    # else
    #   render json: {message: "Outward Report Already In Process and will be sent to email #{current_user.email} Shortly", status: 302}
    # end
  end

  def list_expectional_articles
    exceptional_articles = ExceptionalArticle.all 
    render json: exceptional_articles, root: false
  end

  def list_expectional_article_serial_number
    exceptional_article_serial_numbers = ExceptionalArticleSerialNumber.all 
    render json: exceptional_article_serial_numbers, root: false
  end

  def exp_articles_file_upload
    set_pagination_params(params)
    master_file_uploads = MasterFileUpload.where(master_file_type: params[:file_type]).order('id desc').page(@current_page).per(@per_page)
    render json: master_file_uploads, meta: pagination_meta(master_file_uploads)
  end

  def exp_articles_sr_no_length_mapping
    master_data = MasterDataInput.create(payload: params.except(:forward_master_datum, :controller, :action), master_data_type: 'ExpArticleSerialNumber', status: "Initiated")
    if master_data.save
      MasterDataCreateWorker.perform_async(master_data.id, 'ExpArticleSerialNumber')
      success_json(master_data)
    else
      render json: "Error in creating API Request", status: 422
    end
  end

  def exp_articles_scan_ind_mapping
    master_data = MasterDataInput.create(payload: params.except(:forward_master_datum, :controller, :action), master_data_type: 'ExpArticleScanIndicator', status: "Initiated")
    if master_data.save
      MasterDataCreateWorker.perform_async(master_data.id, 'ExpArticleScanIndicator')
      success_json(master_data)
    else
      render json: "Error in creating API Request", status: 422
    end
  end


  def permit_param
    params.permit!
  end

  def success_json(master_data)
    render json: {"Timestamp": master_data.created_at.strftime("%Y%m%d_%H%M%S"),
                  "Status": "SUCCESS",
                  "Msg": "#{master_data.payload.size} records got created successfully for processing",
                  "Error": []
                 }, status: 200
  end

  def error_json(master_data)
    render json: {"Timestamp": master_data.created_at.strftime("%Y%m%d_%H%M%S"),
                  "Status": "ERROR",
                  "Msg": "Error in creating master data",
                  "Error": [{
                    "Errors": "#{master_data.errors.join(', ')}"
                  }]
                 }, status: 422
  end

  def check_header
    request.headers["Subscription-Key"] == Rails.application.credentials.subscription_key
  end

  def render_message
    render json: { message: "Subscription-Key header is invalid" }
  end

  def get_report_status(type)
    report = current_user.report_statuses.where(distribution_center_ids: current_user.distribution_centers.pluck(:id), status: 'In Process', report_type: type, created_at: (Time.zone.now - 4.hour)..(Time.zone.now))
    if report.present?
      return true
    else
      current_user.report_statuses.create(status: 'In Process', report_type: type, distribution_center_ids: current_user.distribution_centers.pluck(:id))
      return false
    end
  end

end