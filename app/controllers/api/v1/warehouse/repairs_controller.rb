class Api::V1::Warehouse::RepairsController < ApplicationController

  # def index
  #   @repairs = Repair.order('updated_at desc').all
  #   render json: @repairs, include:  ['job_sheet', 'job_sheet.job_sheet_parts'] if @repairs.present?
  #   render json: "Data not Present", status: :unprocessable_entity if @repairs.blank?
  # end


  # def pending_repair
  #   #{repair_id -> 1, action => "save and close", job_sheet -> {id => "", "tentitive_grade" = "Good"}, job_sheet_part -> [{id => "", defect=> physical, type_of_defec=> scratches, part_required=> part_id, quantity => 2, amount=> "100.0", remarks=> "test" , images => []},  {id => "", defect=> functional, type_of_defec=> scratches, part_required=> part_id, quantity => 2, amount=> "100.0", remarks=> "test"}]}
   
  #   ActiveRecord::Base.transaction do
  #     repair = Repair.find(params["id"])
  #     if params["action_name"] == "Submit"
  #       qc_repair_status = LookupValue.where(code:  Rails.application.credentials.repair_status_repair_qc).first
  #       repair.update(status_id: qc_repair_status.id)
  #       repair.details["job_sheet_submission_date"] = Time.now.to_s
  #       repair.save
  #     else
  #       repair.details["pending_draft"] = true
  #       repair.save
  #       repair.update_attributes(updated_at: Time.now.to_s)
  #     end

  #     params["job_sheet_part"].each do |jsp|
  #       job_sheet_part = JobSheetPart.find(jsp["id"])
  #       repaired_bool = jsp["repaired"] == "Yes" ? true : false 
  #       details = job_sheet_part.details
  #       details["submission_remarks"] = jsp["submission_remarks"]
  #       job_sheet_part.update(repaired: repaired_bool , details: details)
  #       if jsp["images"].present?
  #         job_sheet_part.details["images"] = []
  #         jsp["images"].each do |image_url|
  #           job_sheet_part.details["images"].push(image_url)
  #         end
  #         job_sheet_part.save
  #       end
  #     end

  #   end # Transaciton end
  #   render json:"Success"

  # end

  # def upload
  #   img_data = params[:image_url]
  #   file_name = "item_#{rand(1000000).to_s}"
  #   data_uri_parts = img_data.match(/\Adata:([-\w]+\/[-\w\+\.]+)?;base64,(.*)/m) || []
  #   extension = "png"
  #   path_name = "public/uploads/#{file_name}.#{extension}"

  #   service = AWS::S3.new(:access_key_id => Rails.application.credentials.access_key_id,
  #                            :secret_access_key => Rails.application.credentials.secret_access_key  , region: Rails.application.credentials.aws_s3_region)
  #   bucket_name = Rails.application.credentials.aws_bucket

  #   bucket = service.buckets[bucket_name]

  #   bucket.acl = :public_read
    
  #   key = path_name
  #   s3_file = service.buckets[bucket_name].objects.create(key,Base64.decode64(data_uri_parts[2]),{content_type:'image/png', content_encoding: 'base64',acl:"public_read"})
  #   path_name=path_name[6..path_name.length]
  #   url = s3_file.public_url.to_s + "&" + params["row_id"].to_s
  #   render json: {path_name: url}
  # end

  # def delete_images

  #   service = AWS::S3.new(:access_key_id => Rails.application.credentials.access_key_id,
  #                            :secret_access_key => Rails.application.credentials.secret_access_key  , region: Rails.application.credentials.aws_s3_region)
  #   bucket_name = Rails.application.credentials.aws_bucket

  #   Aws.config.update(
  #   credentials: Aws::Credentials.new(Rails.application.credentials.access_key_id, Rails.application.credentials.secret_access_key),
  #   region: "ap-south-1"
  #   )

  #   params[:url].each do |u|

  #     b = u.split('/')
  #     path = b[3..b.length].join('/')
     
  #     s3 = Aws::S3::Resource.new.bucket(Rails.application.credentials.aws_s3_region)
  #     obj = s3.object(path)
  #     obj.delete
  #   end
  #   render json: "success"
  # end

  # def create_job_sheet
  #   JobSheetPart.where(id: params["deleted_parts_ids"]).destroy_all if params["deleted_parts_ids"].present?
  #   repair = Repair.find(params[:id])
  #   job_sheet = JobSheet.where(repair_id: repair.id)
  #   grade = LookupValue.where(original_code: params["job_sheet"]["tentitive_grade"]).first
  #   if job_sheet.blank?
  #     JobSheet.create(repair_id: repair.id, grade_id: grade.id) if grade.present?
  #   else
  #     job_sheet.last.update_attributes(grade_id: grade.id) if grade.present?
  #   end
  #   params["job_sheet_part"].each do |part|
  #     job_sheet_part = repair.job_sheet.job_sheet_parts.find_or_create_by(id: part['id'])
  #     job_sheet_part.update_attributes(repair_part_id: part["part_required"],
  #       quantity: part["quantity"], amount: part["amount"],
  #       details: {"defect" => part["defect"], "type_of_defect" => part["type_of_defect"],
  #         "remarks" => part["remarks"]}
  #     )
  #   end
  #   if params["action_name"] == "Submit"
  #     status = LookupValue.where(code:  Rails.application.credentials.repair_status_pending_repair).first
  #     repair.update_attributes(status_id: status.id)
  #     repair.details["repair_initiation_date"] = Time.now.to_s
  #     repair.save
  #   else
  #     repair.update_attributes(updated_at: Time.now.to_s)
  #   end
  # end
end