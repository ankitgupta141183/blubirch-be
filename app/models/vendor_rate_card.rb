class VendorRateCard < ApplicationRecord
  belongs_to :vendor_master

  def self.import(master_file_upload_id)
    errors_hash = Hash.new(nil)
    error_found = false
    master_file_upload = MasterFileUpload.find_by(id: master_file_upload_id)
    i = 0
    if master_file_upload.present?
      begin
        temp_file = open(master_file_upload.master_file.url)
        file = File.new(temp_file)
        data = CSV.read(file.path, {headers: true, encoding: "iso-8859-1:utf-8"})

        VendorRateCard.transaction do
          data.each_with_index do |row, index|
            i += 1
            row_number = (i+1)
            move_to_next = false
            errors_hash.merge!(row_number => [])

            if row["SKU ID (Article ID)"].blank?
              error_found = true
              error_row = prepare_error_hash(row, row_number, "SKU ID (Article ID) is Mandatory for Vendor Rate Card")
              errors_hash[row_number] << error_row
              move_to_next = true
            elsif ClientSkuMaster.where(code: row["SKU ID (Article ID)"]).blank?
              error_found = true
              error_row = prepare_error_hash(row, row_number, "SKU ID (Article ID) doesn't match")
              errors_hash[row_number] << error_row
              move_to_next = true
            end

            if row["MRP"].blank?
              error_found = true
              error_row = prepare_error_hash(row, row_number, "MRP is Mandatory for Vendor Rate Card")
              errors_hash[row_number] << error_row
              move_to_next = true
            end

            if row["Item Condition"].blank?
              error_found = true
              error_row = prepare_error_hash(row, row_number, "Item Condition is Mandatory for Vendor Rate Card")
              errors_hash[row_number] << error_row
              move_to_next = true
            elsif ["A", "AA", "B", "C", "D", "Not Tested"].exclude?(row["Item Condition"])
              error_found = true
              error_row = prepare_error_hash(row, row_number, "Item Condition '#{row["Item Condition"]}' doesn't match")
              errors_hash[row_number] << error_row
              move_to_next = true
            end

            if row["Contracted Rate"].blank?
              error_found = true
              error_row = prepare_error_hash(row, row_number, "Contracted Rate is Mandatory for Vendor Rate Card")
              errors_hash[row_number] << error_row
              move_to_next = true
            end

            next if move_to_next
            vendor_master = VendorMaster.find_by(id: master_file_upload.vendor_master_id)
            rate_card = vendor_master.vendor_rate_cards.find_or_initialize_by(sku_master_code: row["SKU ID (Article ID)"], item_condition: row["Item Condition"])
            rate_card.update(sku_description: row["SKU or Article Description"], mrp: row["MRP"], contracted_rate: row["Contracted Rate"], contracted_rate_percentage: row["Contracted Rate Percentage"])
          end
        end
      ensure
        if error_found
          all_error_messages = errors_hash.values.flatten.collect{|h| h[:message].to_s}
          all_error_message_str = all_error_messages.join(',')
          master_file_upload.update(status: "Halted", remarks: all_error_message_str)
          return false
        else
          if (data.count == 0)
            master_file_upload.update(status: "Halted", remarks: "File is Empty")
            return false
          else
            master_file_upload.update(status: "Completed")
            return true
          end
        end
      end
    end
  end

  def self.to_csv(vendor_id)
    vendor_master = VendorMaster.find_by(id: vendor_id)
    attributes = ["SKU ID (Article ID)", "SKU or Article Description",  "MRP" , "Item Condition",  "Contracted Rate", "Contracted Rate Percentage"]
    file_csv =  CSV.generate do |csv|
      csv << attributes
      vendor_master.vendor_rate_cards.each do |rate_card|
        contracted_rate_percentage = ((rate_card.mrp/rate_card.contracted_rate)*100).round(2) rescue "N/A"
        csv << [rate_card.sku_master_code, rate_card.sku_description, rate_card.mrp, rate_card.item_condition, rate_card.contracted_rate, contracted_rate_percentage]
      end
    end
    amazon_s3 = Aws::S3::Resource.new(region: Rails.application.credentials.aws_s3_region, access_key_id: Rails.application.credentials.access_key_id, secret_access_key: Rails.application.credentials.secret_access_key)
    bucket = Rails.application.credentials.aws_bucket
    time = Time.now.strftime("%F %H:%M:%S").to_s.tr('-', '')
    file_name = "rate_card_data_#{time.parameterize.underscore}"
    obj = amazon_s3.bucket(bucket).object("uploads/#{file_name}.csv")
    obj.put(body: file_csv, acl: 'public-read', content_disposition: 'attachment', content_type: 'text/csv')
    obj.public_url
  end

  def self.prepare_error_hash(row, rownubmer, message)
    message = "Error In row number (#{rownubmer}) : " + message.to_s
    return {row: row, row_number: rownubmer, message: message}
  end
end
