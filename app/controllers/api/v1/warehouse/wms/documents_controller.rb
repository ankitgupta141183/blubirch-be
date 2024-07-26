class Api::V1::Warehouse::Wms::DocumentsController < ApplicationController

	skip_before_action :check_permission
  before_action :permit_param

	def search		
		if params[:document_number].present?			
			if current_user.present?
				gate_pass_status_assigned = LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_assigned).first
				gate_pass_status_pending_receipt = LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_pending_receipt).first
				gate_pass_status_open = LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_open).first
				gate_pass_status_scanning_in_progress = LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_scanning_in_progress).first
				status_id = [gate_pass_status_open.try(:id), gate_pass_status_assigned.try(:id), gate_pass_status_pending_receipt.try(:id), gate_pass_status_scanning_in_progress.try(:id)]
				gate_pass = GatePass.includes(:distribution_center, :assigned_user).where("lower(client_gatepass_number) = ? or lower(client_gatepass_number) = ? or lower(client_gatepass_number) = ? and (distribution_centers.site_category != ? or document_type != ?)", params[:document_number].try(:downcase), params[:document_number].try(:downcase).sub(/^[0:]*/,""), "0#{params[:document_number].try(:downcase)}", "A", "GI").references(:distribution_centers).first
				if gate_pass.present?
					if current_user.distribution_centers.collect(&:id).include?(gate_pass.distribution_center_id)
						if status_id.include?(gate_pass.try(:status_id))
							if gate_pass.try(:assigned_user).blank?
								if gate_pass.update(assigned_user_id: current_user.id, assigned_at: Time.now, assigned_status: true, status_id: gate_pass_status_assigned.try(:id), status: gate_pass_status_assigned.try(:original_code))
									render json: gate_pass
								else
									render json: "Error in assigning document", status: 422
								end
							elsif (gate_pass.try(:assigned_user).present? && (gate_pass.try(:assigned_user_id) == current_user.try(:id)) || (gate_pass.is_forward == false))
								render json: gate_pass
							elsif gate_pass.try(:assigned_user).present? && (gate_pass.try(:assigned_user_id) != current_user.try(:id))
								render json: "Document already assigned to username '#{gate_pass.try(:assigned_user).try(:username)}'", status: 422
							end	
						elsif status_id.include?(gate_pass.try(:status_id)) == false
							render json: "This document has already been completed", status: 422											
						end
					else
						render json: "You are not authorized to access this document number", status: 422
					end
				else
					render json: "Document Number is not present in system", status: 422
				end
			else
				render json: "Please login again to scan document", status: 401
			end
		else
			render json: "Please enter document number to proceed", status: 422
		end
	end

	def outbound_search		
		if params[:document_number].present?			
			if current_user.present?
				gate_pass_status_assigned = LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_assigned).first
				gate_pass_status_pending_receipt = LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_pending_receipt).first
				gate_pass_status_open = LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_open).first
				gate_pass_status_scanning_in_progress = LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_scanning_in_progress).first
				status_id = [gate_pass_status_open.try(:id), gate_pass_status_assigned.try(:id), gate_pass_status_pending_receipt.try(:id), gate_pass_status_scanning_in_progress.try(:id)]
				outbound_document = OutboundDocument.includes(:distribution_center, :assigned_user).where("lower(client_gatepass_number) = ? or lower(client_gatepass_number) = ? or lower(client_gatepass_number) = ?", params[:document_number].try(:downcase), params[:document_number].try(:downcase).sub(/^[0:]*/,""), "0#{params[:document_number].try(:downcase)}").references(:distribution_centers).first
				if outbound_document.present?
					if current_user.distribution_centers.collect(&:id).include?(outbound_document.source_id)
						if status_id.include?(outbound_document.try(:status_id))
							if outbound_document.try(:assigned_user).blank?
								if outbound_document.update(assigned_user_id: current_user.id, assigned_at: Time.now, assigned_status: true, status_id: gate_pass_status_assigned.try(:id), status: gate_pass_status_assigned.try(:original_code))
									render json: outbound_document
								else
									render json: "Error in assigning document", status: 422
								end
							elsif (outbound_document.try(:assigned_user).present? && (outbound_document.try(:assigned_user_id) == current_user.try(:id)))
								render json: outbound_document
							elsif outbound_document.try(:assigned_user).present? && (outbound_document.try(:assigned_user_id) != current_user.try(:id))
								render json: "Document already assigned to username '#{outbound_document.try(:assigned_user).try(:username)}'", status: 422
							end	
						elsif status_id.include?(outbound_document.try(:status_id)) == false
							render json: "This document has already been completed", status: 422											
						end
					else
						render json: "You are not authorized to access this document number", status: 422
					end
				else
					render json: "Document Number is not present in system", status: 422
				end
			else
				render json: "Please login again to scan document", status: 401
			end
		else
			render json: "Please enter document number to proceed", status: 422
		end
	end

	def ean_search
		sku_ean = SkuEan.where("lower(ean) = ?", params[:ean].try(:downcase)).first
		if sku_ean.present?
			render json: sku_ean
		else
			render json: "EAN Number is not present in system", status: 422
		end
	end

	def users_list
		users = User.all
		render json: users
	end

	def dc_list
		distribution_centers = DistributionCenter.where("site_category in (?)", ["D", "A", "E", "I", "R", "W", "Z"])
		render json: distribution_centers
	end

	def assign_user
		gate_pass = GatePass.where("id in (?)", params[:document_id]).first 
		if gate_pass.present? && gate_pass.update(assigned_user_id: params[:id])
			render json: gate_pass
		else
			render json: "Error in assigning user", status: 422
		end
	end

	def assign_outbound_user
		outbound_document = OutboundDocument.where("id in (?)", params[:document_id]).first 
		if outbound_document.present? && outbound_document.update(assigned_user_id: params[:id])
			render json: outbound_document
		else
			render json: "Error in assigning user", status: 422
		end
	end

	def lookups
		category_code = ["0181","0182","0188","0189","0190","0191","0192","0193","0194","0514","0515","0516","0524","0548","0553","0579","0580","0581","0582","0583","0584","0585","0586","0587","0746"] if Rails.env == "production"
		articles = ["000000000000248935","000000000000248933","000000000000248932","000000000000248931","000000000000248927","000000000000248926","000000000000248925","000000000000247597","000000000000247596","000000000000247595","000000000000247594","000000000000247593","000000000000247592","000000000000245652","000000000000245651","000000000000245015","000000000000244448","000000000000244447","000000000000244446","000000000000244445","000000000000243629","000000000000243628","000000000000243625","000000000000243624","000000000000243623","000000000000243622","000000000000243621","000000000000243620","000000000000243613","000000000000243612","000000000000243611","000000000000243610","000000000000241910","000000000000239159","000000000000237655","000000000000236728","000000000000236727","000000000000236726","000000000000236725","000000000000236724","000000000000236723","000000000000236722","000000000000236721","000000000000235540","000000000000235539","000000000000234747","000000000000234339","000000000000234338","000000000000234337","000000000000234336","000000000000234335","000000000000234334","000000000000234333","000000000000234332","000000000000234331","000000000000234330","000000000000234329","000000000000234328","000000000000234327","000000000000234326","000000000000234325","000000000000234324","000000000000234323","000000000000234322","000000000000234321","000000000000234320","000000000000233723","000000000000229829","000000000000229828","000000000000229542","000000000000229134","000000000000229133","000000000000229132","000000000000229131","000000000000229130","000000000000229129","000000000000229128","000000000000229127","000000000000229126","000000000000229125","000000000000228719","000000000000228534","000000000000228533","000000000000228532","000000000000228531","000000000000228530","000000000000228319","000000000000226706","000000000000226705","000000000000226704","000000000000224231","000000000000224230","000000000000166322","000000000000249477","000000000000249479","000000000000249485","000000000000249489","000000000000249490","000000000000249501","000000000000249865","000000000000249866","000000000000249867","000000000000249868","000000000000249869","000000000000249870","000000000000249871","000000000000249872","000000000000249883","000000000000249884"]  if Rails.env == "production"
		category_code = ["0081","0174","0175","0181","0192","0191","0192","0227","0169","0463","0122","0506", "0514", "0515"] if Rails.env == "development"
		articles = ["000000000000248935","000000000000248933","000000000000248932","000000000000248931","000000000000248927","000000000000248926","000000000000248925","000000000000247597","000000000000247596","000000000000247595","000000000000247594","000000000000247593","000000000000247592","000000000000245652","000000000000245651","000000000000245015","000000000000244448","000000000000244447","000000000000244446","000000000000244445","000000000000243629","000000000000243628","000000000000243625","000000000000243624","000000000000243623","000000000000243622","000000000000243621","000000000000243620","000000000000243613","000000000000243612","000000000000243611","000000000000243610","000000000000241910","000000000000239159","000000000000237655","000000000000236728","000000000000236727","000000000000236726","000000000000236725","000000000000236724","000000000000236723","000000000000236722","000000000000236721","000000000000235540","000000000000235539","000000000000234747","000000000000234339","000000000000234338","000000000000234337","000000000000234336","000000000000234335","000000000000234334","000000000000234333","000000000000234332","000000000000234331","000000000000234330","000000000000234329","000000000000234328","000000000000234327","000000000000234326","000000000000234325","000000000000234324","000000000000234323","000000000000234322","000000000000234321","000000000000234320","000000000000233723","000000000000229829","000000000000229828","000000000000229542","000000000000229134","000000000000229133","000000000000229132","000000000000229131","000000000000229130","000000000000229129","000000000000229128","000000000000229127","000000000000229126","000000000000229125","000000000000228719","000000000000228534","000000000000228533","000000000000228532","000000000000228531","000000000000228530","000000000000228319","000000000000226706","000000000000226705","000000000000226704","000000000000224231","000000000000224230","000000000000166322","000000000000249477","000000000000249479","000000000000249485","000000000000249489","000000000000249490","000000000000249501","000000000000249865","000000000000249866","000000000000249867","000000000000249868","000000000000249869","000000000000249870","000000000000249871","000000000000249872","000000000000249883","000000000000249884"] if Rails.env == "development"
		short_reasons = ["Short received", "Wrong received"]
		render json: { category_code: category_code, articles: articles, short_reasons: short_reasons }
	end

	def index
		set_pagination_params(params)
		documents = GatePass.includes(:gate_pass_inventories).where("document_type = ? and client_gatepass_number is not null", params[:document_type]).page(@current_page).per(@per_page)
		if current_user.present?
			render json: documents, meta: pagination_meta(documents)
		else
			render json: "Please login again to fetch document data", status: 401
		end
	end

	def list_outbound_documents
		set_pagination_params(params)
		documents = OutboundDocument.includes(:outbound_document_articles).where("document_type = ? and client_gatepass_number is not null", params[:document_type]).page(@current_page).per(@per_page)
		if current_user.present?
			render json: documents, meta: pagination_meta(documents)
		else
			render json: "Please login again to fetch document data", status: 401
		end
	end

	def search_documents
		set_pagination_params(params)
		search_param = params['search'].split(',').collect(&:strip).flatten
		documents = GatePass.includes(:gate_pass_inventories).where("lower(#{params['search_in']}) IN (?) and document_type = ? and client_gatepass_number is not null", search_param.map(&:downcase), params[:document_type]).page(@current_page).per(@per_page)
		if current_user.present?
			render json: documents, meta: pagination_meta(documents)
		else
			render json: "Please login again to fetch document data", status: 401
		end
	end

	def search_outbound_documents
		set_pagination_params(params)
		search_param = params['search'].split(',').collect(&:strip).flatten
		documents = OutboundDocument.includes(:outbound_document_articles).where("lower(#{params['search_in']}) IN (?) and document_type = ? and client_gatepass_number is not null", search_param.map(&:downcase), params[:document_type]).page(@current_page).per(@per_page)
		if current_user.present?
			render json: documents, meta: pagination_meta(documents)
		else
			render json: "Please login again to fetch document data", status: 401
		end
	end

	def get_item_list
		gate_pass = GatePass.includes(:gate_pass_inventories).where("id = ?", params[:id]).first
		gate_pass_status_completed = LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_completed).first
		gate_pass_status_closed = LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_closed).first
		if current_user.present?
			if gate_pass.present? 
				if (gate_pass.status_id == gate_pass_status_completed.id || gate_pass.status_id == gate_pass_status_closed.id) 
					render json: gate_pass.inventories, each_serializer: ItemListSerializer
				else
					render json: gate_pass.gate_pass_inventories, each_serializer: ItemListSerializer
				end
			else
				render json: "Document Number is not present in system", status: 422
			end
		else
			render json: "Please login again to scan document", status: 401
		end
	end

	def get_outbound_item_list
		outbound_document = OutboundDocument.includes(:outbound_document_articles).where("id = ?", params[:id]).first
		gate_pass_status_completed = LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_completed).first
		gate_pass_status_closed = LookupValue.where("code = ?", Rails.application.credentials.gate_pass_status_closed).first
		if current_user.present?
			if outbound_document.present? 
				if (outbound_document.status_id == gate_pass_status_completed.id || outbound_document.status_id == gate_pass_status_closed.id) 
					render json: outbound_document.outbound_inventories, each_serializer: OutboundItemListSerializer
				else
					render json: outbound_document.outbound_document_articles, each_serializer: OutboundItemListSerializer
				end
			else
				render json: "Document Number is not present in system", status: 422
			end
		else
			render json: "Please login again to scan document", status: 401
		end
	end

	def get_error_documents
		set_pagination_params(params)
		master_data_inputs = MasterDataInput.where(is_error: true).order("id DESC").page(@current_page).per(@per_page)
		render json: master_data_inputs, meta: pagination_meta(master_data_inputs)
	end

	def barcode_config
		file = File.read("#{Rails.root}/public/barcode_config/barcode.json")
		data_hash = JSON.parse(file)
		render json: {data: data_hash}
	end

	def permit_param
    params.permit!
  end

end
