# frozen_string_literal: true

module Api
  module V1
    module Warehouse
      class PrdController < ApplicationController
        before_action :set_item, only: [:show, :update]

        def index
          set_pagination_params(params)
          filter_prd_items

          @prd_items = @prd_items.page(@current_page).per(@per_page)
          render json: @prd_items, each_serializer: PrdSerializer, meta: pagination_meta(@prd_items)
        end
        
        def filters_data
          irrd_types = PendingReceiptDocument::IRRD_TYPES.map{|i| {id: i, name: i}}

          locations = DistributionCenter.where("site_category in (?)", ["D", "R", "B", "E"]).as_json(only: [:id, :code])

          render json: { irrd_types: irrd_types, locations: locations }
        end

        PRD_ITEM_FIELDS = %i[prd_number tag_number sku_code sku_description quantity brand model scan_indicator imei_flag serial_number1 serial_number2 box_number mrp asp sales_price map purchase_price type_of_damage type_of_loss estimated_loss purchase_invoice_number doa_certificate_number receiving_site_id brand_approval_required]
        def show
          data = @prd_item.as_json(only: PRD_ITEM_FIELDS)
          data['incident_date'] = format_date(@prd_item.incident_date)
          data['sales_invoice_date'] = format_date(@prd_item.sales_invoice_date)
          data['installation_date'] = format_date(@prd_item.installation_date)
          data['purchase_date'] = format_date(@prd_item.purchase_date)
          data['purchase_invoice_date'] = format_date(@prd_item.purchase_invoice_date)
          data['doa_certificate_date'] = format_date(@prd_item.doa_certificate_date)
          
          render json: { prd_item: data }
        end
        
        def update
          ActiveRecord::Base.transaction do
            prd_status_open = LookupValue.find_by(code: 'prd_status_open')
            @prd_item.assign_attributes(prd_item_params)
            # supplying_site = @prd_item.supplying_site_location
            receiving_site = @prd_item.receiving_site_location
            # @prd_item.supplying_site = supplying_site&.code
            @prd_item.receiving_site = receiving_site&.code
            # @prd_item.supplier_organization = supplying_site&.name
            @prd_item.receiving_organization = receiving_site&.name
            @prd_item.save!
            
            @prd_item.update(status: prd_status_open.original_code, status_id: prd_status_open.id)
            
            render json: { message: 'PRD successfully completed.' }
          end
        end

        # IRRD items
        def get_irrd_items
          set_pagination_params(params)
          status = params[:status] || 'Incomplete'
          prd_items = get_items_by_irrd(status)

          prd_items = prd_items.where('pending_receipt_documents.inward_reference_document_number in (?)', params[:search].split_with_gsub) if params[:search].present?
          prd_items = prd_items.page(@current_page).per(@per_page)
          render json: prd_items, each_serializer: PrdSerializer, meta: pagination_meta(prd_items)
        end

        def download_irrd_items
          send_email = params[:send_email] == 'true'
          raise CustomErrors, 'Please enter Email IDs' if send_email and params[:email_ids].blank?

          status = params[:status] || 'Incomplete'
          prd_items = get_items_by_irrd(status)

          file_csv = PendingReceiptDocumentItem.generate_csv(prd_items)
          filename = "#{params[:irrd_number]}-Items.csv"
          if send_email
            subject = "PRD Items by IRRD  #{params[:irrd_number]}"
            PrdMailerWorker.perform_async(file_csv, filename, subject, params[:email_ids].to_a)
            
            render json: { message: "#{params[:irrd_number]} Email sent successfully." }
          else
            send_data(file_csv, filename: filename)
          end
        end

        # IRD items
        def get_ird_items
          set_pagination_params(params)
          status = params[:status] || 'Incomplete'
          prd_items = get_items_by_ird(status)

          prd_items = prd_items.where(sku_code: params[:search].split_with_gsub) if params[:search].present?
          prd_items = prd_items.page(@current_page).per(@per_page)
          render json: prd_items, each_serializer: PrdSerializer, meta: pagination_meta(prd_items)
        end

        def download_ird_items
          send_email = params[:send_email] == 'true'
          raise CustomErrors, 'Please enter Email IDs' if send_email and params[:email_ids].blank?

          status = params[:status] || 'Incomplete'
          prd_items = get_items_by_ird(status)

          file_csv = PendingReceiptDocumentItem.generate_csv(prd_items)
          filename = "#{params[:ird_number]}-Items.csv"
          if send_email
            subject = "PRD Items by IRD  #{params[:ird_number]}"
            PrdMailerWorker.perform_async(file_csv, filename, subject, params[:email_ids].to_a)
            
            render json: { message: "#{params[:ird_number]} Email sent successfully." }
          else
            send_data(file_csv, filename: filename)
          end
        end

        # Approval APIs
        def update_approval
          ActiveRecord::Base.transaction do
            prd_items = get_prd_items
            prd_numbers = prd_items.pluck(:prd_number).join(", ")
            prd_approval_status = LookupValue.find_by(code: 'prd_status_approval')
            
            prd_items.each do |prd_item|
              prd_item.update(status: prd_approval_status.original_code, status_id: prd_approval_status.id, reason_for_deletion: params[:reason_for_deletion], previous_status: prd_item.status)
            end
            
            render json: { status: :ok, message: "#{prd_numbers} sent for Deletion Approval" }
          end
        end

        def delete_items
          ActiveRecord::Base.transaction do
            prd_items = get_prd_items
            prd_numbers = prd_items.pluck(:prd_number).join(", ")

            prd_items.each do |prd_item|
              prd_item.destroy!
            end

            render json: { status: :ok, message: "#{prd_numbers} successfully deleted." }
          end
        end
        
        def reject
          ActiveRecord::Base.transaction do
            prd_items = get_prd_items
            prd_numbers = prd_items.pluck(:prd_number).join(", ")
            prd_incomplete_status = LookupValue.find_by(code: 'prd_status_incomplete')
            prd_open_status = LookupValue.find_by(code: 'prd_status_open')
            
            prd_items.each do |prd_item|
              prd_status = prd_item.previous_status == "Incomplete" ? prd_incomplete_status : prd_open_status
              prd_item.update(status: prd_status.original_code, status_id: prd_status.id)
            end
            
            render json: { status: :ok, message: "#{prd_numbers} successfully rejected." }
          end
        end

        def download_items
          prd_items = get_prd_items

          file_csv = PendingReceiptDocumentItem.generate_csv(prd_items)
          send_data(file_csv, filename: "PRD-Incomplete-Items.csv")
        end
        
        # File Uploads - Both Create PRD and Upload APIs
        def file_uploads
          set_pagination_params(params)
          file_type = params[:file_type] || 'Pending Receipt Document'
          master_file_uploads = MasterFileUpload.where(master_file_type: file_type).order('id desc')
          master_file_uploads = master_file_uploads.where('master_file like ?', "%#{params[:search]}%") if params[:search].present?
          master_file_uploads = master_file_uploads.page(@current_page).per(@per_page)
          
          render json: master_file_uploads, meta: pagination_meta(master_file_uploads)
        end
        
        def upload_file
          ActiveRecord::Base.transaction do
            raise CustomErrors, 'Please upload file' if params[:file].blank?
            master_file_upload = MasterFileUpload.new(master_file: params[:file], user_id: current_user.id)
            file_type = params[:file_type] || 'Pending Receipt Document'
            master_file_upload.master_file_type = file_type
            master_file_upload.status = 'Pending'
            
            if master_file_upload.save
              render json: { master_file_upload: master_file_upload }, status: :created
            else
              render json: master_file_upload.errors, status: :unprocessable_entity
            end
          end
        end
        
        def download_prd_sample
          prd_items = PendingReceiptDocumentItem.order(id: :desc).limit(4)
          file_csv = PendingReceiptDocumentItem.generate_csv(prd_items)
          if params[:upload] == "true"
            filename = 'Upload PRD Sample.csv'
          else
            csv_data = CSV.parse(file_csv, headers: true)
            csv_data.delete("PRD No.")
            file_csv = csv_data.to_csv
            filename = 'Create PRD Sample.csv'
          end
          send_data(file_csv, filename: filename)
        end

        private

        def filter_prd_items
          status = params[:status] || "Incomplete"
          @prd_items = PendingReceiptDocumentItem.includes(:pending_receipt_document).joins(:pending_receipt_document).where(status: status).order(id: :desc)
          
          @prd_items = @prd_items.where(prd_number: params[:search].split_with_gsub) if params[:search].present?
          @prd_items = @prd_items.where(tag_number: params[:tag_number].split_with_gsub) if params[:tag_number].present?
          @prd_items = @prd_items.where(sku_code: params[:sku_code].split_with_gsub) if params[:sku_code].present?
          @prd_items = @prd_items.where('serial_number1 in (?) or serial_number2 in (?)', params[:serial_number].split_with_gsub, params[:serial_number].split_with_gsub) if params[:serial_number].present?
          @prd_items = @prd_items.where('pending_receipt_documents.inward_reason_reference_document_type ilike ?', params[:irrd_type]) if params[:irrd_type].present?
          @prd_items = @prd_items.where('pending_receipt_documents.inward_reason_reference_document_number in (?)', params[:irrd_number].split_with_gsub) if params[:irrd_number].present?
          @prd_items = @prd_items.where('pending_receipt_documents.inward_reference_document_number in (?)', params[:ird_number].split_with_gsub) if params[:ird_number].present?
        end

        def set_item
          @prd_item = PendingReceiptDocumentItem.find_by(id: params[:id])
        end
        
        def prd_item_params
          params.require(:prd_item).permit(PRD_ITEM_FIELDS + %i[incident_date sales_invoice_date installation_date purchase_date purchase_invoice_date doa_certificate_date])
        end
        
        def get_prd_items
          prd_items = PendingReceiptDocumentItem.where(id: params[:ids])
          raise CustomErrors, 'Invalid ID' if prd_items.blank?
          prd_items
        end

        def get_items_by_irrd(status)
          prd_items = PendingReceiptDocumentItem.includes(:pending_receipt_document).joins(:pending_receipt_document).where(status: status)
          prd_items = prd_items.where('pending_receipt_documents.inward_reason_reference_document_number = ?', params[:irrd_number]).order(id: :desc)
          raise CustomErrors, 'Invalid IRRD.' if prd_items.blank?
          prd_items
        end

        def get_items_by_ird(status)
          prd_items = PendingReceiptDocumentItem.includes(:pending_receipt_document).joins(:pending_receipt_document).where(status: status)
          prd_items = prd_items.where('pending_receipt_documents.inward_reference_document_number = ?', params[:ird_number]).order(id: :desc)
          raise CustomErrors, 'Invalid IRD.' if prd_items.blank?
          prd_items
        end
      end
    end
  end
end
