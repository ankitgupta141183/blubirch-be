class ExceptionalArticleSerialNumber < ApplicationRecord

  acts_as_paranoid

	def self.import(master_file_upload_id)
		errors_hash = Hash.new(nil)
    error_found = false
    begin
      master_file_upload = MasterFileUpload.where("id = ?", master_file_upload_id).first
      i = 0

      if master_file_upload.present?
        temp_file = open(master_file_upload.master_file.url)
        file = File.new(temp_file)
        data = CSV.read(file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
        user = User.find(master_file_upload.user_id)      
      end

      ExceptionalArticleSerialNumber.transaction do
        data.each do |row|
        	i += 1
          row_number = (i+1)
          move_to_next = false
          errors_hash.merge!(row_number => [])

		      if row["Article"].blank?
		        error_found = true
		        error_row = prepare_error_hash(row, row_number, "Article is not present")
		        errors_hash[row_number] << error_row
		        move_to_next = true
		      end
          if row["Serial Number Length"].blank?
            error_found = true
            error_row = prepare_error_hash(row, row_number, "Serial Number Length is not present")
            errors_hash[row_number] << error_row
            move_to_next = true
          end
		      
		      next if move_to_next

		      serial_number_length = row["Serial Number Length"].to_i
		      
          exceptional_article = ExceptionalArticleSerialNumber.where("sku_code = ?", format('%018d', "#{row['Article'].try(:strip)}")).last
		      if exceptional_article.present?
		      	exceptional_article.update(serial_number_length: serial_number_length)
		      else
		      	self.create(sku_code: format('%018d', "#{row['Article'].try(:strip)}"), serial_number_length: serial_number_length)
		      end

		    end
		  end
    ensure
      if error_found
        all_error_messages = errors_hash.values.flatten.collect do |h| h[:message].to_s end
        all_error_message_str = all_error_messages.join(',')
        master_file_upload.update(status: "Halted", remarks: all_error_message_str) if master_file_upload.present?
        return false
      else
        if (data.count == 0)
          master_file_upload.update(status: "Halted", remarks: "File is Empty")
          return false
        else  
          master_file_upload.update(status: "Completed", remarks: nil) if master_file_upload.present?
          return true
        end
      end
    end
	end

  def self.create_article_sr_no_mapping(master_data_input_id)
    master_data = MasterDataInput.where("id = ?", master_data_input_id).first
    errors_hash = Hash.new(nil)
    error_found = false
    success_count = 0
    failed_count = 0
    if master_data.present?
      begin
        master_data.payload["payload"].each do |data|
          exceptional_article = ExceptionalArticleSerialNumber.where("sku_code ilike (?)", "%#{data['sku_code']}").last
          if (exceptional_article.blank? && data['sku_status_ind'] == "A")
            exceptional_article = ExceptionalArticleSerialNumber.new(sku_code: data['sku_code'], serial_number_length: data['serial_number_length'], master_data_input_id: master_data.id)
            if exceptional_article.save
              success_count = success_count + 1
            else
              failed_count = failed_count + 1
              errors_hash.merge!(data["sku_code"] => [])
              error_found = true
              error_row = prepare_error(exceptional_article.errors.full_messages.join(","))
              errors_hash[data["sku_code"]] << error_row
            end
          else
            if (data['sku_status_ind'] == "A" && exceptional_article.update(sku_code: data['sku_code'], serial_number_length: data['serial_number_length'], master_data_input_id: master_data.id))
              success_count = success_count + 1
            elsif (data['sku_status_ind'] == "D" && exceptional_article.destroy)
              success_count = success_count + 1
            else
              failed_count = failed_count + 1
              errors_hash.merge!(data["sku_code"] => [])
              error_found = true
              error_row = prepare_error(exceptional_article.errors.full_messages.join(","))
              errors_hash[data["sku_code"]] << error_row
            end
          end
        end
      rescue Exception => message
        master_data.update(status: "Failed", is_error: true, remarks: message.to_s, success_count: success_count, failed_count: failed_count) if master_data.present?
      else
        master_data.update(status: "Completed", is_error: false, success_count: success_count, failed_count: failed_count) if master_data.present?
      ensure
        if error_found
          master_data.update(status: "Completed", is_error: true, remarks: errors_hash, success_count: success_count, failed_count: failed_count) if master_data.present?
        end
      end
    end
  end

	def self.prepare_error_hash(row, rownubmer, message)
    message = "Error In row number (#{rownubmer}) : " + message.to_s
    return {row: row, row_number: rownubmer, message: message}
  end

  def self.prepare_error(message)
    return {message: message}
  end

end
