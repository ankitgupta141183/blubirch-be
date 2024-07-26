class Admin::VendorMastersController < ApplicationController

  def import
    VendorMaster.import(params[:file])
  end

  def index
    if params[:search].present?
      @vendors = VendorMaster.where('vendor_code = ? OR vendor_name = ?', params[:search], params[:search]).page(params[:page]).per(params[:per_page])
    else
      @vendors = VendorMaster.all.page(params[:page]).per(params[:per_page])
    end
    render json: @vendors, meta: pagination_meta(@vendors)
  end

  def delete_vendor
    vendor_master = VendorMaster.find_by_id(params[:vendor_master_id])
    vendor_distribution = vendor_master.vendor_distributions.find_by_id(params[:id])
    if vendor_distribution.present?
      vendor_distribution.delete
      render json: 'Success', status: 200
    else
      render json: {message: "Record Not Found", status: 404}
    end
  end

  def uploaded_rate_cards
    vendor_master = VendorMaster.find_by_id(params[:id])
    where_qry = "master_file ILIKE '%#{params[:file_name]}%'" if params[:file_name].present?
    render json: { uploaded_rate_cards: vendor_master.master_file_uploads.where(where_qry).order(created_at: :desc) }, status: 200
  end

  def export_rate_cards
    VendorRateCardWorker.perform_async(@current_user.id, params[:id])
    render json: 'You will be receiving an email shortly!', status: 200
  end
end