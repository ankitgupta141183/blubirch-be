# frozen_string_literal: true

class ReturnItem < ApplicationRecord
  acts_as_paranoid
  belongs_to :return_inventory_information, optional: true
  belongs_to :client_sku_master, optional: true
  belongs_to :client_category, optional: true
  belongs_to :user
  belongs_to :return_item_status, class_name: 'LookupValue', foreign_key: 'status_id'
  belongs_to :delivery_location, class_name: 'DistributionCenter', optional: true
  belongs_to :client_sku_master, optional: true
  belongs_to :client_category, optional: true

  validates :tag_number, uniqueness: { case_sensitive: false, allow_blank: true }

  enum item_decision: { return: 1, write_off: 2, no_action: 3 }, _prefix: true
  enum repair_location: { customer: 1, item_location: 2 }, _prefix: true
  enum movement_mode: { will_be_delivered: 1, to_be_picked_up: 2 }, _prefix: true
  enum internal_recovery_method: { invoice_to_vendor: 1, invoice_to_employee: 2 }, _prefix: true

  def self.import_file(return_file_upload_id)
    errors_hash = Hash.new(nil)
    error_found = false
    return_file_upload = ReturnFileUpload.where('id = ?', return_file_upload_id).first
    temp_file = open(return_file_upload.return_file.url)
    file = File.new(temp_file)
    data = CSV.read(file, headers: true, encoding: 'iso-8859-1:utf-8')
    user = User.find(return_file_upload.user_id)
    headers = data.headers
    return_creation_pending_eligibility_validation_status = LookupValue.where(code: Rails.application.credentials.return_creation_pending_eligibility_validation_status).first
    return_request_number = generate_return_request_number
    begin
      ActiveRecord::Base.transaction do
        data.each_with_index do |row, index|
          row_number = index + 1
          errors_hash.merge!(row_number => [])

          move_to_next = false
          move_to_next, errors_hash, return_inventory_information, lookup_values_array = check_for_errors(errors_hash, row_number, row, return_file_upload.return_type)

          error_found = true if move_to_next

          next if move_to_next

          return_sub_request_number = generate_return_sub_request_number

          client_sku_master = ClientSkuMaster.where('code = ?', row['SKU Code']).last

          return_request = new(return_request_id: return_request_number, return_sub_request_id: return_sub_request_number,
                               return_type: return_file_upload.return_type, channel: row['Channel'], status_id: return_creation_pending_eligibility_validation_status.try(:id),
                               status: return_creation_pending_eligibility_validation_status.try(:original_code), return_reason: row['Return Reason'],
                               return_sub_reason: row['Return Sub Reason'], return_request_sub_type: row['Return Request Sub Type'],
                               item_location: row['Item Location'], sku_code: row['SKU Code'], reference_document_number: row['Reference Document Number'],
                               reference_document: row['Reference Document'], quantity: row['Quantity'], return_inventory_information_id: return_inventory_information.id,
                               sku_description: return_inventory_information.sku_description, channel_id: lookup_values_array[0], return_reason_id: lookup_values_array[1],
                               return_sub_reason_id: lookup_values_array[2], return_request_sub_type_id: lookup_values_array[3], item_location_id: lookup_values_array[4],
                               return_type_id: lookup_values_array[5], location_id: row['Location ID'], user_id: user.id, serial_number: row['Serial Number'],
                               supplier: return_inventory_information.try(:supplier), mrp: return_inventory_information.try(:mrp), asp: return_inventory_information.try(:asp),
                               map: return_inventory_information.try(:map), category_details: return_inventory_information.category_details, brand: client_sku_master.try(:brand),
                               client_sku_master_id: return_inventory_information.try(:client_sku_master_id), client_category_id: return_inventory_information.try(:client_category_id),
                               category_name: return_inventory_information.try(:category_name))

          return_request.save
        end
      end
    ensure
      all_error_messages = errors_hash.values.flatten.collect { |h| h[:message].to_s }
      all_error_message_str = all_error_messages.join(',')
      if error_found

        return_file_upload.update(status: 'Halted', remarks: all_error_message_str) if return_file_upload.present?
        return false
      else

        return_file_upload.update(status: 'Completed') if return_file_upload.present?

        return true
      end
    end
  end

  def self.check_for_errors(errors_hash, row_number, row, return_creation_type)
    error = ''
    error_found = false
    return_inventory_information = nil

    if return_creation_type.blank?
      error = 'Return Type cannot be blank'
      error_found = true
      error_row = prepare_error_hash(row, row_number, error)
      errors_hash[row_number] << error_row
    elsif return_creation_type.present?
      lookup_key = LookupKey.where('code = ?', Rails.application.credentials.return_types).last
      return_type_lookup_value = LookupValue.where('lookup_key_id = ? and code = ?', lookup_key.id,
                                                   "#{lookup_key.try(:code).try(:downcase).try(:parameterize).try(:underscore)}_#{return_creation_type.try(:downcase).try(:parameterize).try(:underscore)}").last
      if return_type_lookup_value.nil?
        error = "Specified Return Type doesn't exists"
        error_found = true
        error_row = prepare_error_hash(row, row_number, error)
        errors_hash[row_number] << error_row
      end
    end
    if row['Channel'].blank?
      error = 'Channel cannot be blank'
      error_found = true
      error_row = prepare_error_hash(row, row_number, error)
      errors_hash[row_number] << error_row
    elsif row['Channel'].present?
      lookup_key = LookupKey.where('code = ?', Rails.application.credentials.channel_types).last
      channel_lookup_value = LookupValue.where('lookup_key_id = ? and code = ?', lookup_key.id,
                                               "#{lookup_key.try(:code).try(:downcase).try(:parameterize).try(:underscore)}_#{row['Channel'].try(:downcase).try(:parameterize).try(:underscore)}").last
      if channel_lookup_value.nil?
        error = "Specified Channel doesn't exists"
        error_found = true
        error_row = prepare_error_hash(row, row_number, error)
        errors_hash[row_number] << error_row
      end
    end
    if (Rails.application.credentials.sales_return_type == return_creation_type) || (Rails.application.credentials.lease_return_type == return_creation_type) || (Rails.application.credentials.internal_return_type == return_creation_type)
      if row['Return Reason'].blank?
        error = 'Return Reason cannot be blank'
        error_found = true
        error_row = prepare_error_hash(row, row_number, error)
        errors_hash[row_number] << error_row
      elsif row['Return Reason'].present?
        lookup_key = LookupKey.where('code = ?', Rails.application.credentials.return_creation_return_reasons).last
        return_reason_lookup_value = LookupValue.where('lookup_key_id = ? and code = ?', lookup_key.id,
                                                       "#{lookup_key.try(:code).try(:downcase).try(:parameterize).try(:underscore)}_#{row['Return Request Sub Type'].try(:downcase).try(:parameterize).try(:underscore)}_#{row['Return Reason'].try(:downcase).try(:parameterize).try(:underscore)}").last
        if return_reason_lookup_value.nil?
          error = "Specified Return Reason doesn't exists"
          error_found = true
          error_row = prepare_error_hash(row, row_number, error)
          errors_hash[row_number] << error_row
        end
      end
      if row['Return Sub Reason'].blank?
        error = 'Return Sub Reason cannot be blank'
        error_found = true
        error_row = prepare_error_hash(row, row_number, error)
        errors_hash[row_number] << error_row
      elsif row['Return Sub Reason'].present?
        lookup_key = LookupKey.where('code = ?', Rails.application.credentials.return_creation_sub_reasons).last
        return_sub_reason_lookup_value = LookupValue.where('lookup_key_id = ? and code = ?', lookup_key.id,
                                                           "#{lookup_key.try(:code).try(:downcase).try(:parameterize).try(:underscore)}_#{row['Return Reason'].try(:downcase).try(:parameterize).try(:underscore)}_#{row['Return Sub Reason'].try(:downcase).try(:parameterize).try(:underscore)}").last
        if return_sub_reason_lookup_value.nil?
          error = "Specified Return Sub Reason doesn't exists"
          error_found = true
          error_row = prepare_error_hash(row, row_number, error)
          errors_hash[row_number] << error_row
        end
      end
      if row['Return Request Sub Type'].blank?
        error = 'Return Request Sub Type cannot be blank'
        error_found = true
        error_row = prepare_error_hash(row, row_number, error)
        errors_hash[row_number] << error_row
      elsif row['Return Request Sub Type'].present?
        lookup_key = LookupKey.where('code = ?', Rails.application.credentials.return_sub_types).last
        return_request_sub_type_lookup_value = LookupValue.where('lookup_key_id = ? and code = ?', lookup_key.id,
                                                                 "#{lookup_key.try(:code).try(:downcase).try(:parameterize).try(:underscore)}_#{return_creation_type.try(:downcase).try(:parameterize).try(:underscore)}_#{row['Return Request Sub Type'].try(:downcase).try(:parameterize).try(:underscore)}").last
        if return_request_sub_type_lookup_value.nil?
          error = "Specified Return Request Sub Type doesn't exists"
          error_found = true
          error_row = prepare_error_hash(row, row_number, error)
          errors_hash[row_number] << error_row
        end
      end
    end
    if row['Item Location'].blank?
      error = 'Item Location cannot be blank'
      error_found = true
      error_row = prepare_error_hash(row, row_number, error)
      errors_hash[row_number] << error_row
    elsif row['Item Location'].present?
      lookup_key = LookupKey.where('code = ?', Rails.application.credentials.retrun_creation_locations).last
      item_location_lookup_value = LookupValue.where('lookup_key_id = ? and code = ?', lookup_key.id,
                                                     "#{lookup_key.try(:code).try(:downcase).try(:parameterize).try(:underscore)}_#{row['Item Location'].try(:downcase).try(:parameterize).try(:underscore)}").last
      if item_location_lookup_value.nil?
        error = "Specified Location doesn't exists"
        error_found = true
        error_row = prepare_error_hash(row, row_number, error)
        errors_hash[row_number] << error_row
      end
    end
    if row['Quantity'].blank?
      error = 'Quantity cannot be blank'
      error_found = true
      error_row = prepare_error_hash(row, row_number, error)
      errors_hash[row_number] << error_row
    end
    if row['Reference Document Number'].present? || row['Article ID'].present? || row['Serial Number'].present?
      if row['Reference Document Number'].present?
        if row['Serial Number'].present?
          return_inventory_informations = ReturnInventoryInformation.where('LOWER(reference_document_number) ilike (?) and LOWER(serial_number) ilike (?) and available_quantity > 0',
                                                                           "%#{row['Reference Document Number'].try(:downcase)}%", "%#{row['Serial Number'].try(:downcase)}%")
        end
        if row['Article ID'].present?
          return_inventory_informations = ReturnInventoryInformation.where('LOWER(reference_document_number) ilike (?) and LOWER(sku_code) ilike (?) and available_quantity > 0',
                                                                           "%#{row['Reference Document Number'].try(:downcase)}%", "%#{row['SKU Code'].try(:downcase)}%")
        end
      elsif row['Serial Number'].present?
        return_inventory_informations = ReturnInventoryInformation.where('LOWER(serial_number) ilike (?) and available_quantity > 0', "%#{row['Serial Number'].try(:downcase)}%")
      elsif row['SKU Code'].present?
        return_inventory_informations = ReturnInventoryInformation.where('LOWER(sku_code) ilike (?) and available_quantity > 0', "%#{row['SKU Code'].try(:downcase)}%")
      end
      if return_inventory_informations.blank?
        error = "Return Inventory Information for this Reference Document Number:  #{row['Reference Document Number']} / SKU Code: #{row['SKU Code']} / Serial Number: #{row['Serial Number']} is not present"
        error_found = true
        error_row = prepare_error_hash(row, row_number, error)
        errors_hash[row_number] << error_row
      else
        return_inventory_information = return_inventory_informations.last
      end
    else
      error = 'Reference Document Number / Article ID / Serial Number cannot be blank'
      error_found = true
      error_row = prepare_error_hash(row, row_number, error)
      errors_hash[row_number] << error_row
    end

    [error_found, errors_hash, return_inventory_information, [channel_lookup_value.try(:id), return_reason_lookup_value.try(:id), return_sub_reason_lookup_value.try(:id),
                                                              return_request_sub_type_lookup_value.try(:id), item_location_lookup_value.try(:id), return_type_lookup_value.try(:id)]]
  end

  def self.prepare_error_hash(row, rownubmer, message)
    message = "Error In row number (#{rownubmer}) : " + message.to_s
    { row: row, row_number: rownubmer, message: message }
  end

  def self.generate_return_request_number
    rr_number = "RR-#{SecureRandom.hex(3)}".downcase
    return_request = where(return_request_id: rr_number)
    while return_request.present?
      rr_number = "RR-#{SecureRandom.hex(3)}".downcase
      return_request = where(return_request_id: rr_number)
    end
    rr_number
  end

  def self.generate_return_sub_request_number
    rs_number = "RS-#{SecureRandom.hex(3)}".downcase
    return_sub_request = where(return_sub_request_id: rs_number)
    while return_sub_request.present?
      rr_number = "RS-#{SecureRandom.hex(3)}".downcase
      return_sub_request = where(return_sub_request_id: rs_number)
    end
    rs_number
  end

  def self.update_quantity_information(return_items)
    return_items_update_array = []
    ActiveRecord::Base.transaction do
      return_items.each do |return_item|
        if return_item.return_inventory_information.present?
          return_item.return_inventory_information.update!(quantity: return_item.return_inventory_information.quantity.to_i + return_item.quantity.to_i,
                                                           available_quantity: return_item.return_inventory_information.available_quantity.to_i - return_item.quantity.to_i)
          return_items_update_array << true
        else
          return_items_update_array << false
        end
      end
    end
    return_items_update_array.all?
  rescue StandardError
    false
  end

  def self.create_line_items(return_item_params, user)
    return_item_array = []
    error_messages = []
    ActiveRecord::Base.transaction do
      return_request_number = generate_return_request_number
      return_creation_pending_eligibility_validation_status = LookupValue.where(code: Rails.application.credentials.return_creation_pending_eligibility_validation_status).first
      return_item_params['return_details'].each do |return_item_param|
        return_sub_request_number = generate_return_sub_request_number
        return_inventory_information = ReturnInventoryInformation.where('id = ?', return_item_param['return_inventory_information_id']).last
        client_sku_master = ClientSkuMaster.where('code = ?', return_item_param['sku_code']).last
        if return_inventory_information.available_quantity.positive?
          return_item = new(return_request_id: return_request_number, return_sub_request_id: return_sub_request_number,
                            return_type: return_item_params['return_type'], channel: return_item_params['channel'], status_id: return_creation_pending_eligibility_validation_status.try(:id),
                            status: return_creation_pending_eligibility_validation_status.try(:original_code), return_reason: return_item_params['return_reason'],
                            return_sub_reason: return_item_params['return_sub_reason'], return_request_sub_type: return_item_params['return_request_sub_type'],
                            item_location: return_item_params['item_location'], sku_code: return_item_param['sku_code'], reference_document_number: return_item_param['reference_document_number'],
                            reference_document: return_item_param['reference_document'], quantity: return_item_param['quantity'], return_inventory_information_id: return_inventory_information.id,
                            sku_description: return_inventory_information.sku_description, channel_id: return_item_params['channel_id'], return_reason_id: return_item_params['return_reason_id'],
                            return_sub_reason_id: return_item_params['return_reason_id'], return_request_sub_type_id: return_item_params['return_request_sub_type_id'], item_location_id: return_item_params['item_location_id'],
                            return_type_id: return_item_params['return_type_id'], location_id: return_item_params['location_id'], user_id: user.id, type_of_incident_or_damage: return_item_params['type_of_incident_or_damage'],
                            type_of_incident_or_damage_id: return_item_params['type_of_incident_or_damage_id'], type_of_loss: return_item_params['type_of_loss'],
                            type_of_loss_id: return_item_params['type_of_loss_id'], estimated_loss: return_item_params['estimated_loss'],
                            salvage_value: return_item_params['salvage_value'], salvage_value_id: return_item_params['salvage_value_id'], incident_date: return_item_params['incident_date'],
                            incident_location: return_item_params['incident_location'], vendor_responsible: return_item_params['vendor_responsible'],
                            vendor_responsible_id: return_item_params['vendor_responsible_id'], incident_report_number: return_item_params['incident_report_number'],
                            serial_number: return_item_param['serial_number'], preffered_settlement_method: return_item_params['preffered_settlement_method'], preffered_settlement_method_id: return_item_params['preffered_settlement_method_id'],
                            supplier: return_inventory_information.try(:supplier), mrp: return_inventory_information.try(:mrp), asp: return_inventory_information.try(:asp),
                            map: return_inventory_information.try(:map), category_details: return_inventory_information.category_details, brand: client_sku_master.try(:brand),
                            client_sku_master_id: return_inventory_information.try(:client_sku_master_id), client_category_id: return_inventory_information.try(:client_category_id),
                            category_name: return_inventory_information.try(:category_name))
        else
          error_messages << "Quantity is not available for this Reference Document Number: #{return_inventory_information.reference_document_number} SKU Code: #{return_inventory_information.sku_code} Serial Number: #{return_inventory_information.serial_number}"
        end
        if return_item.save
          return_item_array << true
          return_inventory_information.update(available_quantity: return_inventory_information.available_quantity.to_i - return_item.quantity.to_i)
        else
          return_item_array << false
          error_messages << "Error in this line item of Reference Document Number: #{return_inventory_information.reference_document_number} SKU Code: #{return_inventory_information.sku_code} Serial Number: #{return_inventory_information.serial_number}"
        end
      end
    end
    if return_item_array.all?
      [true, error_messages]
    else
      [false, error_messages]
    end
  end

  def self.generate_irrd
    loop do
      @irrd = SecureRandom.random_number(10_000_000)
      break if ReturnItem.where(irrd_number: @irrd).blank?
    end
    @irrd
  end

  def self.generate_ird
    loop do
      @ird = SecureRandom.random_number(1_000_000)
      break if ReturnItem.where(ird_number: @ird).blank?
    end
    @ird
  end

  def item_amount
    return_inventory_information&.item_value.to_f
  end

  def pickup_location
    if item_location == 'Customer'
      'Customer'
    else
      location_id
    end
  end

  def get_delivery_location
    dc_location = if item_location == 'Customer'
                    DcLocation.find_by(pincode: return_inventory_information.customer_pincode)
                  else
                    DcLocation.find_by(dc_code: location_id)
                  end
    self.delivery_location = dc_location&.distribution_center || DistributionCenter.first
  end
end
