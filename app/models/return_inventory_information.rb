# frozen_string_literal: true

class ReturnInventoryInformation < ApplicationRecord
  acts_as_paranoid

  belongs_to :user
  belongs_to :return_inventory_status, class_name: 'LookupValue', foreign_key: :status_id
  belongs_to :client_sku_master, optional: true
  belongs_to :client_category, optional: true

  def self.import(file_upload_id)
    errors_hash = Hash.new(nil)
    error_found = false
    file_upload = MasterFileUpload.where('id = ?', file_upload_id).last
    temp_file = open(file_upload.master_file.url)
    file = File.new(temp_file)
    data = CSV.read(file, headers: true, encoding: 'iso-8859-1:utf-8')
    headers = data.headers
    return_inventory_information_new_status = LookupValue.where('code = ?', Rails.application.credentials.return_inventory_information_new_status).last
    begin
      ActiveRecord::Base.transaction do
        data.each_with_index do |row, index|
          row_number = index + 1
          errors_hash.merge!(row_number => [])

          move_to_next = false
          move_to_next, errors_hash = check_for_errors(errors_hash, row_number, row)

          error_found = true if move_to_next

          next if move_to_next

          client_sku_master = ClientSkuMaster.where(code: row['SKU Code']).last

          return_inventory_inforamtion = ReturnInventoryInformation.new(reference_document: row['Reference Document'], reference_document_number: row['Reference Document Number'], sku_code: row['SKU Code'],
                                                                        sku_description: row['SKU Description'], serial_number: row['Serial Number'], quantity: row['Quantity'], order_date: row['Order Date'],
                                                                        item_value: row['Item Amount'], total_amount: row['Total Amount'], status: return_inventory_information_new_status.try(:original_code),
                                                                        status_id: return_inventory_information_new_status.try(:id), customer_name: row['Customer Name'], customer_email: row['Customer Email'],
                                                                        customer_phone: row['Customer Phone'], customer_address_line1: row['Customer Address Line 1'], customer_address_line2: row['Customer Address Line 2'],
                                                                        customer_address_line3: row['Customer Address Line 3'], customer_city: row['Customer City'], customer_state: row['Customer State'], customer_country: row['Customer Country'],
                                                                        customer_pincode: row['Customer Pincode'], user_id: file_upload.user_id, available_quantity: row['Quantity'], supplier: client_sku_master.try(:supplier),
                                                                        mrp: client_sku_master.try(:mrp), asp: client_sku_master.try(:asp), map: client_sku_master.try(:map), category_details: client_sku_master.description,
                                                                        brand: client_sku_master.try(:brand), client_sku_master_id: client_sku_master.try(:id), client_category_id: client_sku_master.try(:client_category_id),
                                                                        category_name: client_sku_master.try(:client_category).try(:name))

          return_inventory_inforamtion.save
        end
        raise ActiveRecord::Rollback, 'Please check error hash' if error_found
      end
    ensure
      all_error_messages = errors_hash.values.flatten.collect { |h| h[:message].to_s }
      all_error_message_str = all_error_messages.join(',')
      if error_found

        file_upload.update(status: 'Error', remarks: all_error_message_str) if file_upload.present?
        return false
      else

        file_upload.update(status: 'Completed') if file_upload.present?
        return true
      end
    end
  end

  def self.check_for_errors(errors_hash, row_number, row)
    error = ''
    error_found = false

    if row['Reference Document Number'].present? && row['Reference Document'].blank?
      error = "Reference Document can't be blank"
      error_found = true
      error_row = prepare_error_hash(row, row_number, error)
      errors_hash[row_number] << error_row
    end

    if row['Reference Document'].present? && row['Reference Document Number'].blank?
      error = "Reference Document Number can't be blank"
      error_found = true
      error_row = prepare_error_hash(row, row_number, error)
      errors_hash[row_number] << error_row
    end

    if row['SKU Code'].blank?
      error = "SKU Code can't be blank"
      error_found = true
      error_row = prepare_error_hash(row, row_number, error)
      errors_hash[row_number] << error_row
    end

    if row['Quantity'].blank? && row['Serial Number'].present?
      row['Quantity'] = 1
    elsif row['Quantity'].blank? && row['Serial Number'].blank?
      error = "Quantity can't be blank"
      error_found = true
      error_row = prepare_error_hash(row, row_number, error)
      errors_hash[row_number] << error_row
    end

    [error_found, errors_hash]
  end

  def self.prepare_error_hash(row, rownubmer, message)
    message = "Error in row number (#{rownubmer}) : " + message.to_s
    { row: row, row_number: rownubmer, message: message }
  end
end
