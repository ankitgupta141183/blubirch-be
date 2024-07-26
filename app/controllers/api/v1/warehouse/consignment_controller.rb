class Api::V1::Warehouse::ConsignmentController < ApplicationController
  
  def get_logistics_partners
    locations = current_user.distribution_centers.distinct.as_json(only: [:id, :code])
    logistics_partners = LogisticsPartner.all.as_json(only: [:id, :name])
    
    render json: { locations: locations, logistics_partners: logistics_partners }
  end
  
  def generate_receipt_summary
    ActiveRecord::Base.transaction do
      consignment_params = params[:consignment]
      raise 'Please enter Consignment ID' and return if consignment_params[:consignment_id].blank?
      
      if consignment_params[:other_logistics_partner].present?
        logistics_partner = LogisticsPartner.create(name: consignment_params[:other_logistics_partner])
      else
        logistics_partner = LogisticsPartner.find_by(id: consignment_params[:logistics_partner_id].to_i)
      end
      
      consignment = Consignment.new({
        consignment_id: consignment_params[:consignment_id], distribution_center_id: consignment_params[:distribution_center_id], logistics_partner_id: logistics_partner.id,
        status: :initiated, user_id: current_user.id
      })
      consignment.save!
      
      consignment_params[:dispatch_documents].each do |dispatch_document|
        consignment_info = ConsignmentInformation.create_consignment_info(consignment, dispatch_document)
      end
      
      consignment_data = consignment.generate_receipt
      render json: { consignment: consignment_data, status: :ok }
    end
  end
  
  def submit_consignment_details
    ActiveRecord::Base.transaction do
      consignment = Consignment.find_by(id: params[:id])
      raise 'Invalid ID' and return if consignment.blank?
      raise 'Please upload Acknowledgement Receipt' and return if params[:acknowledgement_receipt].blank?
      
      consignment.acknowledgement_receipt = params[:acknowledgement_receipt]
      consignment.damage_certificates = params[:damage_certificates] if params[:damage_certificates].present?
      consignment.status = :submitted
      consignment.save!
      
      render json: { message: "DDNs added successfully", status: :ok }
    end
  end

  private
  
  
  def permissions
    {
      inwarder: {
        "api/v1/warehouse/consignment": %i[get_logistics_partners generate_receipt_summary submit_consignment_details]
      },
      central_admin: {
        "api/v1/warehouse/consignment": %i[get_logistics_partners generate_receipt_summary submit_consignment_details]
      },
      site_admin: {
        "api/v1/warehouse/consignment": %i[get_logistics_partners generate_receipt_summary submit_consignment_details]
      },
      default_user: {
        "api/v1/warehouse/consignment": %i[get_logistics_partners generate_receipt_summary submit_consignment_details]
      }
    }
  end
end