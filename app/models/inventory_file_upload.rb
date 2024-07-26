class InventoryFileUpload < ApplicationRecord
  acts_as_paranoid
  mount_uploader :inventory_file,  ConsignmentFileUploader

  include JsonUpdateable

  belongs_to :user
  belongs_to :client, optional: true

  # after_save :upload_file

  def upload_file
    InventoryFileUploadWorker.perform_async(id)
  end

  def self.upload_pending_files
    InventoryFileUpload.where(status: 'Import Started').each do |inventory|
      InventoryFileUploadWorker.new.perform(inventory.id)
    end
  end

  def self.import_lots(inventory_file_upload_id)
    errors_hash = Hash.new(nil)
    error_found = false
    lot_error_found = false
    lot_errors = []
    dc_items = []
    db_grades = LookupKey.where(name: 'STANDALONE_INVENTORY_GRADE').last.lookup_values.pluck(:original_code) rescue []
    inventory_file_upload = InventoryFileUpload.where("id = ?", inventory_file_upload_id).first
    data = CSV.parse(open(inventory_file_upload.inventory_file.url), headers: true, encoding:'iso-8859-1:utf-8')
    lot_type = LookupValue.find_by(code: Rails.application.credentials.liquidation_lot_type_beam_lot)
    lot_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_pending_publish)
    new_liquidation_status = LookupValue.where(code: Rails.application.credentials.liquidation_status_pending_publish_status).first
    service_liquidation = []
    
    begin
      i = 1
      ActiveRecord::Base.transaction do
        data.each_with_index do |row, index|
          i = i+1
          row_number = i
          loop_error = false
          if row.to_hash.values.any?
            move_to_next = false
            errors_hash.merge!(row_number => [])
            if row["Tag Number"].blank?
              error_found = true
              loop_error = true
              error_row = prepare_error_hash(row, row_number, "Tag Number is blank")
              errors_hash[row_number] << error_row
              move_to_next = true
              item = Liquidation.find_by(tag_number: row['Tag Number'], is_active: true)
              inv = Inventory.find_by(tag_number: row['Tag Number'])
            end
            next if loop_error
            if row["Lot Name"].blank?
              error_found = true
              loop_error = true
              error_row = prepare_error_hash(row, row_number, "Lot Name is blank")
              errors_hash[row_number] << error_row
              move_to_next = true
            end
            next if loop_error
            if row["MRP"].blank?
              error_found = true
              loop_error = true
              error_row = prepare_error_hash(row, row_number, "MRP is blank")
              errors_hash[row_number] << error_row
              move_to_next = true
            end
            next if loop_error


            if row['Tag Number'].present?
              item = Liquidation.find_by(tag_number: row['Tag Number'], is_active: true)
              inv = Inventory.find_by(tag_number: row['Tag Number'])
              dc_items.push(inv.distribution_center_id) if inv.present?
              if item.blank? || inv.blank?
                error_found = true
                loop_error = true
                if inv.blank?
                  error_row = prepare_error_hash(row, row_number, "Tag #{row['Tag Number']} is not present in our system")
                elsif item.blank?
                  error_row = prepare_error_hash(row, row_number, "Tag #{row['Tag Number']} is present in #{inv.get_current_bucket.class.name}")
                end
                errors_hash[row_number] << error_row
                move_to_next = true
              end
            end

            if dc_items.present?
              if dc_items.uniq.size > 1
                error_found = true
                error_row = prepare_error_hash(row, row_number, "Please Provide Only One Distribution Center Items Only")
                errors_hash[row_number] << error_row
                move_to_next = true
                loop_error = true
              end
            end

            next if loop_error
            liquidation_items = Liquidation.where(tag_number: row["Tag Number"], is_active: true, status: ['Pending Lot Creation', 'Pending RFQ'])
            if liquidation_items.blank?
              error_found = true
              loop_error = true
              error_row = prepare_error_hash(row, row_number, "Tag #{row['Tag Number']} number is in #{Liquidation.where(tag_number: row["Tag Number"], is_active: true).last.status}")
              errors_hash[row_number] << error_row
              move_to_next = true
            end
            next if loop_error
            liquidation_items.each do |liquidation_item|
              if liquidation_item.present? && liquidation_item.liquidation_order_id.nil?
                service_liquidation << liquidation_item.id
                liquidation_item.update_attributes(lot_name: row["Lot Name"], mrp: row["MRP"], floor_price: row["Floor Price"])
                liquidation_item.inventory.update(item_price: row["MRP"])
              else
                error_found = true
                loop_error = true
                error_row = prepare_error_hash(row, row_number, "Tag number is already mapped to Lot")
                errors_hash[row_number] << error_row
                move_to_next = true
              end
            end
          end
        end
        # liquidation order creation starts
        if error_found || errors_hash.values.flatten.present?
          all_error_messages = errors_hash.values.flatten.collect do |h| h[:message].to_s end
          all_error_message_str = all_error_messages.join(',')
          inventory_file_upload.update_columns(status: "Failed", remarks: all_error_message_str) if inventory_file_upload.present?
          return false
        else
          @liquidations = Liquidation.where(id: service_liquidation, liquidation_order_id: nil)
          all_liquidations = @liquidations.reject {|i| i.lot_name.nil?}.group_by{ |c| c.lot_name }

          all_liquidations.each do |lot_name, liquidations|
            lot_mrp = liquidations.inject(0){|sum,x| (sum + x.mrp.to_i) if x.mrp.present? }
            lot_floor_price = liquidations.inject(0){|sum,x| (sum + x.floor_price.to_i)}
            liquidation_order = LiquidationOrder.new(lot_name: lot_name, lot_desc: lot_name, mrp: lot_mrp, floor_price: lot_floor_price, status:lot_status.original_code, status_id: lot_status.id, order_amount: lot_mrp, quantity: liquidations.count, lot_type: lot_type.original_code, lot_type_id: lot_type.id)
            if liquidation_order.save
              liquidation_order_history = LiquidationOrderHistory.create(liquidation_order_id:liquidation_order.id, status: lot_status.original_code, status_id: lot_status.id)

              liquidations.each do |liquidation|
                liquidation_item = liquidation
                if liquidation_item.present?
                    liquidation_item.update( liquidation_order_id: liquidation_order.id , status: new_liquidation_status.original_code , status_id: new_liquidation_status.id, lot_type: lot_type.original_code, lot_type_id: lot_type.id)
                    LiquidationHistory.create(
                      liquidation_id: liquidation_item.id , 
                      status_id: new_liquidation_status.try(:id), 
                      status: new_liquidation_status.try(:original_code))
                end
              end
              liquidation_order.tags =  liquidation_order.liquidations.pluck(:tag_number)
              liquidation_order.details ||= {}
              liquidation_order.details['master_file_id'] = inventory_file_upload_id
              liquidation_order.details['master_lot_file_url'] = inventory_file_upload.inventory_file.url
              liquidation_order.save 
            else
              lot_error_found = true
              lot_errors << (liquidation_order.lot_name+":" + liquidation_order.errors.full_messages.flatten.join(","))
            end
          end
        end
        # liquidation order creation ends
        raise ActiveRecord::Rollback if (error_found || lot_error_found)
      end
    rescue Exception => message
      inventory_file_upload.update_columns(status: "Failed", remarks: "Line Number #{i}:"+message.to_s)
    else
      inventory_file_upload.update_columns(status: "Completed")
    ensure
      if error_found && lot_error_found
        all_error_messages = errors_hash.values.flatten.collect do |h| h[:message].to_s end
        all_error_message_str = all_error_messages.join(',')
        inventory_file_upload.update_columns(status: "Failed", remarks: all_error_message_str+','+lot_errors.flatten.join(",")) if inventory_file_upload.present?
        return false
      elsif error_found
        all_error_messages = errors_hash.values.flatten.collect do |h| h[:message].to_s end
        all_error_message_str = all_error_messages.join(',')
        inventory_file_upload.update_columns(status: "Failed", remarks: all_error_message_str) if inventory_file_upload.present?
        return false
      elsif lot_error_found
        inventory_file_upload.update_columns(status: "Failed", remarks: lot_errors.flatten.join(",")) if inventory_file_upload.present?
        return false
      end
    end
  end

  def self.import_competitive_lots(inventory_file_upload_id)
    inventory_file_upload = InventoryFileUpload.find_by("id = ?", inventory_file_upload_id)
    data = CSV.parse(open(inventory_file_upload.inventory_file.url), headers: true, encoding:'iso-8859-1:utf-8')
    lot_type = LookupValue.find_by(code: Rails.application.credentials.liquidation_lot_type_competitive_lot)
    lot_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_pending_lot_details)
    current_user = User.find_by(id: inventory_file_upload.user_id)

    errors_hash = Hash.new(nil)
    error_found = false
    lot_error_found = false
    lot_errors = []
    service_liquidation = []
    begin
      ActiveRecord::Base.transaction do
        data.each_with_index do |row, i|
          row_number = i + 2
          if row.to_hash.values.any?
            move_to_next = false
            errors_hash.merge!(row_number => [])
            item = Liquidation.find_by(tag_number: row['Tag Number'], is_active: true, status: 'Competitive Bidding Price')

            if item.blank?
              error_found = true
              error_row = prepare_error_hash(row, row_number, "Item having tag number #{row['Tag Number']} is not present in system")
              errors_hash[row_number] << error_row
              move_to_next = true
            elsif item.liquidation_order_id.present?
              error_found = true
              error_row = prepare_error_hash(row, row_number, "Tag number is already mapped to Lot")
              errors_hash[row_number] << error_row
              move_to_next = true
            end
            next if move_to_next

            ["Title", "Lot Name", "Site Location", "Tag Number", "Item Type", "Brand", "MRP (in INR)", "Quantity", "Grade", "Item Description", "Floor Price"].each do |column|
              if row["#{column}"].blank?
                error_found = true
                error_row = prepare_error_hash(row, row_number, "#{column} is blank")
                errors_hash[row_number] << error_row
                move_to_next = true
              end
            end

            (1..6).each do |level|
              if item.details["Category L#{level}"].present? && row["Category L#{level}"] != item.details["category_l#{level}"]
                error_found = true
                error_row = prepare_error_hash(row, row_number, "'Category L#{level}' is not matching with item 'Category L#{level}'")
                errors_hash[row_number] << error_row
                move_to_next = true
              end
            end

            if row["Quantity"].to_i != 1
              error_found = true
              error_row = prepare_error_hash(row, row_number, "Quantity for the tag #{row['Tag Number']} must be 1.")
              errors_hash[row_number] << error_row
              move_to_next = true
            end

            next if move_to_next
            liquidation_items = Liquidation.where(tag_number: row["Tag Number"], is_active: true, status: 'Competitive Bidding Price')
            liquidation_items.each do |liquidation_item|
              if liquidation_item.present? && liquidation_item.liquidation_order_id.nil?
                service_liquidation << liquidation_item.id
                inventory = liquidation_item.inventory
                liquidation_item.update_attributes(lot_name: row["Lot Name"], item_description: row["Item Description"], floor_price: row["Floor Price"], item_price: inventory.item_price)
                inventory.details['manual_remarks'] = row['Remarks']
                inventory.details["model"] = row["Model"]
                inventory.details["sub-model/variant"] = row["Sub-Model/ Variant"]
                inventory.save
              else
                error_found = true
                error_row = prepare_error_hash(row, row_number, "Tag number is already mapped to Lot")
                errors_hash[row_number] << error_row
                move_to_next = true
              end
            end
          end
        end

        if error_found || errors_hash.values.flatten.present?
          all_error_messages = errors_hash.values.flatten.collect do |h| h[:message].to_s end
          all_error_message_str = all_error_messages.join(',')
          inventory_file_upload.update_columns(status: "Failed", remarks: all_error_message_str) if inventory_file_upload.present?
          return false
        else
          @liquidations = Liquidation.where(id: service_liquidation, liquidation_order_id: nil)
          all_liquidations = @liquidations.reject {|i| i.lot_name.nil?}.group_by{ |c| c.lot_name }

          all_liquidations.each do |lot_name, liquidations|
            next unless lot_name
            lot_mrp = liquidations.inject(0){|sum,x| (sum + x.item_price.to_i) if x.item_price.present? }
            lot_floor_price = liquidations.inject(0){|sum,x| (sum + x.floor_price.to_i)}
            liquidation_ids = liquidations.pluck(:id).uniq
            tags = liquidations.pluck(:tag_number).compact.uniq
            details = { 'master_lot_file_url' => inventory_file_upload.inventory_file&.url }
            lot_params = {
              lot: {
                lot_name: lot_name,
                mrp: lot_mrp,
                order_amount: lot_mrp,
                floor_price: lot_floor_price,
                status:lot_status.original_code,
                status_id: lot_status.id,
                quantity: liquidation_ids&.count,
                lot_type: lot_type.original_code,
                lot_type_id: lot_type.id,
                details: details,
                tags: tags,
                created_by_id: current_user.id,
                distribution_center_id: liquidations.pluck(:distribution_center_id).first
              },
              liquidation_ids: liquidation_ids,
            }
            liquidation_order = LiquidationOrder.create_lot(lot_params, current_user)
            if liquidations.pluck(:distribution_center_id).uniq.count > 1
              lot_error_found = true
              lot_errors << "#{liquidation_order.lot_name} : all liquidation item should be same distribution center"
            end
            if liquidations.pluck(:is_ewaste).uniq.compact.count > 1
              lot_error_found = true
              lot_errors << "#{liquidation_order.lot_name} : all liquidation item should be either ewaste or non ewaste"
            end
          end
        end
        # liquidation order creation ends
        raise ActiveRecord::Rollback if (error_found || lot_error_found)
      end
    rescue Exception => message
      inventory_file_upload.update_columns(status: "Failed", remarks: "error: "+message.to_s)
    else
      inventory_file_upload.update_columns(status: "Completed")
    ensure
      if error_found && lot_error_found
        all_error_messages = errors_hash.values.flatten.collect do |h| h[:message].to_s end
        all_error_message_str = all_error_messages.join(',')
        inventory_file_upload.update_columns(status: "Failed", remarks: all_error_message_str+','+lot_errors.flatten.join(",")) if inventory_file_upload.present?
        return false
      elsif error_found
        all_error_messages = errors_hash.values.flatten.collect do |h| h[:message].to_s end
        all_error_message_str = all_error_messages.join(',')
        inventory_file_upload.update_columns(status: "Failed", remarks: all_error_message_str) if inventory_file_upload.present?
        return false
      elsif lot_error_found
        inventory_file_upload.update_columns(status: "Failed", remarks: lot_errors.flatten.join(",")) if inventory_file_upload.present?
        return false
      end
    end
  end

  def self.import_email_lots(inventory_file_upload_id)
    errors_hash = Hash.new(nil)
    error_found = false
    lot_error_found = false
    lot_errors = []
    dc_items = []
    inventory_file_upload = InventoryFileUpload.where("id = ?", inventory_file_upload_id).first
    data = CSV.parse(open(inventory_file_upload.inventory_file.url), headers: true, encoding:'iso-8859-1:utf-8')
    lot_type = LookupValue.find_by(code: Rails.application.credentials.liquidation_lot_type_email_lot)
    lot_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_pending_closure)
    new_liquidation_status = LookupValue.where(code: Rails.application.credentials.liquidation_status_pending_publish_status).first
    service_liquidation = []

    begin
      i = 1
      ActiveRecord::Base.transaction do
        data.each_with_index do |row, index|
          i = i+1
          row_number = i
          loop_error = false
          if row.to_hash.values.any?
            move_to_next = false
            errors_hash.merge!(row_number => [])
            if row["Tag Number"].blank?
              error_found = true
              error_row = prepare_error_hash(row, row_number, "Tag Number is blank")
              errors_hash[row_number] << error_row
              move_to_next = true
              loop_error = true
            end
            next if loop_error
            if row["Lot Name"].blank?
              error_found = true
              error_row = prepare_error_hash(row, row_number, "Lot Name is blank")
              errors_hash[row_number] << error_row
              move_to_next = true
              loop_error = true
            end
            next if loop_error
            if row["MRP"].blank?
              error_found = true
              error_row = prepare_error_hash(row, row_number, "MRP is blank")
              errors_hash[row_number] << error_row
              move_to_next = true
              loop_error = true
            end
            next if loop_error
            if row['Tag Number'].present?
              item = Liquidation.find_by(tag_number: row['Tag Number'], is_active: true)
              inv = Inventory.find_by(tag_number: row['Tag Number'])
              dc_items.push(inv.distribution_center_id) if inv.present?
              if item.blank? || inv.blank?
                error_found = true
                loop_error = true
                if inv.blank?
                  error_row = prepare_error_hash(row, row_number, "Tag #{row['Tag Number']} is not present in our system")
                elsif item.blank?
                  error_row = prepare_error_hash(row, row_number, "Tag #{row['Tag Number']} is present in #{inv.get_current_bucket.class.name}")
                end
                errors_hash[row_number] << error_row
                move_to_next = true
              end
            end

            if dc_items.present?
              if dc_items.uniq.size > 1
                error_found = true
                error_row = prepare_error_hash(row, row_number, "Please Provide Only One Distribution Center Items Only")
                errors_hash[row_number] << error_row
                move_to_next = true
                loop_error = true
              end
            end

            next if loop_error

            liquidation_items = Liquidation.includes(:inventory, :liquidation_order).where(tag_number: row["Tag Number"], is_active: true, status: ['Pending Lot Creation', 'Pending RFQ'])
            if liquidation_items.blank?
              error_found = true
              loop_error = true
              error_row = prepare_error_hash(row, row_number, "Tag #{row['Tag Number']} number is in #{Liquidation.where(tag_number: row["Tag Number"], is_active: true).last.status}")
              errors_hash[row_number] << error_row
              move_to_next = true
            end
            next if loop_error
            liquidation_items.each do |liquidation_item|
              if liquidation_item.present? && liquidation_item.liquidation_order_id.nil?
                if liquidation_item.update_attributes(lot_name: row["Lot Name"], mrp: row["MRP"], floor_price: row["Expected Price"])
                  service_liquidation << liquidation_item.id
                  liquidation_item.inventory.update_attributes(item_price: row["MRP"])
                else
                  error_found = true
                  loop_error = true
                  error_row = prepare_error_hash(row, row_number, "Tag #{row['Tag Number']} #{liquidation_item.errors.full_messages.join(', ')}")
                  errors_hash[row_number] << error_row
                  move_to_next = true
                end
              else
                error_found = true
                loop_error = true
                error_row = prepare_error_hash(row, row_number, "Tag #{row['Tag Number']} number is already mapped to Lot")
                errors_hash[row_number] << error_row
                move_to_next = true
              end
            end
          end
        end
        # liquidation order creation starts
        if error_found || errors_hash.values.flatten.present?
          all_error_messages = errors_hash.values.flatten.collect do |h| h[:message].to_s end
          all_error_message_str = all_error_messages.join(',')
          inventory_file_upload.update_columns(status: "Failed", remarks: all_error_message_str) if inventory_file_upload.present?
          return false
        else
          @liquidations = Liquidation.where(id: service_liquidation, is_active: true, status: ['Pending Lot Creation', 'Pending RFQ'], liquidation_order_id: nil)
          all_liquidations = @liquidations.reject {|i| i.lot_name.nil?}.group_by{ |c| c.lot_name }

          all_liquidations.each do |lot_name, liquidations|
            lot_mrp = liquidations.inject(0){|sum,x| (sum + x.mrp.to_i) if x.mrp.present? }
            lot_floor_price = liquidations.inject(0){|sum,x| (sum + x.floor_price.to_i)}
            liquidation_order = LiquidationOrder.new(lot_name: lot_name, lot_desc: lot_name, order_amount: lot_floor_price, floor_price: lot_floor_price, status:lot_status.original_code, status_id: lot_status.id, mrp: lot_mrp, quantity: liquidations.count, lot_type: lot_type.original_code, lot_type_id: lot_type.id)
            if liquidation_order.save
              liquidation_order_history = LiquidationOrderHistory.create(liquidation_order_id:liquidation_order.id, status: lot_status.original_code, status_id: lot_status.id, details: {"Pending_Closure_created_date" => Time.now.to_s })

              liquidations.each do |liquidation_item|
                liquidation_item.update_attributes( liquidation_order_id: liquidation_order.id , status: new_liquidation_status.original_code , status_id: new_liquidation_status.id, lot_type: lot_type.original_code, lot_type_id: lot_type.id)
                LiquidationHistory.create(
                  liquidation_id: liquidation_item.id , 
                  status_id: new_liquidation_status.try(:id), 
                  status: new_liquidation_status.try(:original_code))
              end
              liquidation_order.tags =  liquidation_order.liquidations.pluck(:tag_number)
              liquidation_order.details ||= {}
              liquidation_order.details['master_file_id'] = inventory_file_upload_id
              liquidation_order.details['master_lot_file_url'] = inventory_file_upload.inventory_file.url
              liquidation_order.save
            else
              lot_error_found = true
              lot_errors << (liquidation_order.lot_name+":" + liquidation_order.errors.full_messages.flatten.join(","))
            end
          end
        end
        # liquidation order creation ends
        raise ActiveRecord::Rollback if (error_found || lot_error_found)
      end
    rescue Exception => message
      inventory_file_upload.update_columns(status: "Failed", remarks: "Line Number #{i}:"+message.to_s)
    else
      inventory_file_upload.update_columns(status: "Completed")
    ensure
      if error_found && lot_error_found
        all_error_messages = errors_hash.values.flatten.collect do |h| h[:message].to_s end
        all_error_message_str = all_error_messages.join(',')
        inventory_file_upload.update_columns(status: "Failed", remarks: all_error_message_str+','+lot_errors.flatten.join(",")) if inventory_file_upload.present?
        return false
      elsif error_found
        all_error_messages = errors_hash.values.flatten.collect do |h| h[:message].to_s end
        all_error_message_str = all_error_messages.join(',')
        inventory_file_upload.update_columns(status: "Failed", remarks: all_error_message_str) if inventory_file_upload.present?
        return false
      elsif lot_error_found
        inventory_file_upload.update_columns(status: "Failed", remarks: lot_errors.flatten.join(",")) if inventory_file_upload.present?
        return false
      end
    end
  end


  def self.edit_grade(inventory_file_upload_id)

    errors_hash = Hash.new(nil)
    error_found = false
    lot_error_found = false
    lot_errors = []
    inventory_file_upload = InventoryFileUpload.where("id = ?", inventory_file_upload_id).first
    data = CSV.parse(open(inventory_file_upload.inventory_file.url), headers: true, encoding:'iso-8859-1:utf-8')
    new_liquidation_status = LookupValue.find_by_original_code('Pending Lot Creation')
    service_liquidation = []

    begin
      i = 1
      ActiveRecord::Base.transaction do
        data.each_with_index do |row, index|
          i = i+1
          row_number = i
          loop_error = false
          if row.to_hash.values.any?
            move_to_next = false
            errors_hash.merge!(row_number => [])
            if row["Tag Number"].blank?
              error_found = true
              loop_error = true
              error_row = prepare_error_hash(row, row_number, "Tag Number is blank")
              errors_hash[row_number] << error_row
              move_to_next = true
            end
            next if loop_error

            if row["Grade"].blank?
              error_found = true
              loop_error = true
              error_row = prepare_error_hash(row, row_number, "Grade is blank")
              errors_hash[row_number] << error_row
              move_to_next = true
            end
            next if loop_error

            if row["Grade"].present? && !['A1', 'AA', 'A', 'B', 'C', 'D', 'Not Tested'].include?(row["Grade"])
              error_found = true
              loop_error = true
              error_row = prepare_error_hash(row, row_number, "Please Provide Valid Grade Input")
              errors_hash[row_number] << error_row
              move_to_next = true
            end
            next if loop_error

            if row['Tag Number'].present?
              item = Liquidation.find_by(tag_number: row['Tag Number'], is_active: true)
              inv = Inventory.find_by(tag_number: row['Tag Number'])

              if item.blank? || inv.blank?
                error_found = true
                loop_error = true
                if inv.blank?
                  error_row = prepare_error_hash(row, row_number, "Tag #{row['Tag Number']} is not present in our system")
                elsif item.blank?
                  error_row = prepare_error_hash(row, row_number, "Tag #{row['Tag Number']} is present in #{inv.get_current_bucket.class.name}")
                end
                errors_hash[row_number] << error_row
                move_to_next = true
              end
            end
            next if loop_error
            liquidation_item = Liquidation.where(tag_number: row["Tag Number"], is_active: true, status: ['Pending Lot Creation', 'Pending Liquidation Regrade', 'Pending RFQ']).last
            if liquidation_item.blank?
              error_found = true
              loop_error = true
              error_row = prepare_error_hash(row, row_number, "Tag #{row['Tag Number']} number is in #{Liquidation.where(tag_number: row["Tag Number"], is_active: true).last.status}")
              errors_hash[row_number] << error_row
              move_to_next = true
            end
            next if loop_error


            own_label = ClientSkuMaster.find_by(code: liquidation_item.inventory.sku_code).own_label
            if !own_label
              error_found = true
              loop_error = true
              error_row = prepare_error_hash(row, row_number, "Tag #{row['Tag Number']} number Grade is not Updated item type is Non Own Label")
              errors_hash[row_number] << error_row
              move_to_next = true
            end
            next if loop_error

            if liquidation_item.present?
              service_liquidation << [liquidation_item.id, row["Grade"]]
            else
              error_found = true
              loop_error = true
              error_row = prepare_error_hash(row, row_number, "Tag number is already mapped to Lot")
              errors_hash[row_number] << error_row
              move_to_next = true
            end
          end
        end

        if error_found || errors_hash.values.flatten.present?
          all_error_messages = errors_hash.values.flatten.collect do |h| h[:message].to_s end
          all_error_message_str = all_error_messages.join(',')
          inventory_file_upload.update_columns(status: "Failed", remarks: all_error_message_str) if inventory_file_upload.present?
          return false
        else
          service_liquidation.each do |item|
            grade = item[1]
            liquidation_item = Liquidation.includes(:inventory).find_by(id: item[0])
            if liquidation_item.grade != item[1].try(:strip)
              remarks_grade = "A brand-new, unused, unopened item in its original packaging, with all original packaging materials included. Packaging might have minor scratches or damages. Since it is seal packed, functional & physical condition of the item is not checked by Bulk4Traders team" if (grade == "A1" || grade == "AA")
              remarks_grade = "The product is well-cared-for and is fully functional but may show minor physical or cosmetic blemishes and/ or the item may have some accessories missing. The packaging might have been replaced to protect the item. The product has been tested by the Bulk4Traders team."  if grade == "A"
              remarks_grade = "The item shows normal marks from consistent use, but it remains in good condition and works fully. It may show other signs of previous use and/ or the item may have some accessories missing. The packaging might be missing or might have major damages. The product has been tested by the Bulk4Traders team."  if grade == "B"
              remarks_grade = "The product may have minor functional issues and/ or the item is fairly worn. Signs of wear can include aesthetic issues such as scratches, dents, worn corners and cracks/damage on body. The item may have identifying markings on it or show other signs of previous use. Packaging may or may not be present and packaging condition may be bad. The product has been tested by the Bulk4Traders team."  if grade == "C"
              remarks_grade = "The product may be functionally defective and/ or physically damaged. Packaging may or may not be present and packaging condition may be bad. The product has been tested by the Bulk4Traders team."  if (grade == "D" || grade == "E")
              remarks_grade = "These items have not been inspected by Bulk4Traders team or have been physically inspected but not functionally checked. These are being sold in “As-is” condition. Some of these items could be working order while some may not be fully functional. These may not come with original packaging, manuals and/or supplementary accessories such as batteries and chargers."  if grade == "Not Tested"
              liquidation_item.inventory.update(grade: grade, details: liquidation_item.merge_details({"manual_grade_changed" => "true", "previous_grade" => liquidation_item.grade, "manual_remarks" => remarks_grade}))
              liquidation_item.update(grade: grade, details: liquidation_item.merge_details({"manual_grade_changed" => "true", "previous_grade" => liquidation_item.grade, "manual_remarks" => remarks_grade}))
            end
          end
        end
        raise ActiveRecord::Rollback if (error_found || lot_error_found)
      end
    rescue Exception => message
      inventory_file_upload.update_columns(status: "Failed", remarks: "Line Number #{i}:"+message.to_s)
    else
      inventory_file_upload.update_columns(status: "Completed")
    ensure
      if error_found && lot_error_found
        all_error_messages = errors_hash.values.flatten.collect do |h| h[:message].to_s end
        all_error_message_str = all_error_messages.join(',')
        inventory_file_upload.update_columns(status: "Failed", remarks: all_error_message_str+','+lot_errors.flatten.join(",")) if inventory_file_upload.present?
        return false
      elsif error_found
        all_error_messages = errors_hash.values.flatten.collect do |h| h[:message].to_s end
        all_error_message_str = all_error_messages.join(',')
        inventory_file_upload.update_columns(status: "Failed", remarks: all_error_message_str) if inventory_file_upload.present?
        return false
      elsif lot_error_found
        inventory_file_upload.update_columns(status: "Failed", remarks: lot_errors.flatten.join(",")) if inventory_file_upload.present?
        return false
      end
    end
  end

  def self.import_contract_lots(inventory_file_upload_id)
    errors_hash = Hash.new(nil)
    error_found = false
    lot_error_found = false
    lot_errors = []
    dc_items = []
    inventory_file_upload = InventoryFileUpload.where("id = ?", inventory_file_upload_id).first
    data = CSV.parse(open(inventory_file_upload.inventory_file.url), headers: true, encoding:'iso-8859-1:utf-8')
    lot_type = LookupValue.find_by(code: "liquidation_lot_type_contract_lot")
    lot_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_pending_publish)
    new_liquidation_status = LookupValue.where(code: Rails.application.credentials.liquidation_status_pending_publish_status).first
    service_liquidation = []
    begin
      i = 1
      ActiveRecord::Base.transaction do
        data.each_with_index do |row, index|
          i = i+1
          row_number = i
          loop_error = false
          if row.to_hash.values.any?
            move_to_next = false
            errors_hash.merge!(row_number => [])
            if row["Tag Number"].blank?
              error_found = true
              loop_error = true
              error_row = prepare_error_hash(row, row_number, "Tag Number is blank")
              errors_hash[row_number] << error_row
              move_to_next = true
              item = Liquidation.find_by(tag_number: row['Tag Number'], is_active: true)
              inv = Inventory.find_by(tag_number: row['Tag Number'])
            end
            next if loop_error
            if row["Lot Name"].blank?
              error_found = true
              loop_error = true
              error_row = prepare_error_hash(row, row_number, "Lot Name is blank")
              errors_hash[row_number] << error_row
              move_to_next = true
            end
            next if loop_error
            if row["MRP"].blank?
              error_found = true
              loop_error = true
              error_row = prepare_error_hash(row, row_number, "MRP is blank")
              errors_hash[row_number] << error_row
              move_to_next = true
            end
            next if loop_error
            if row['Tag Number'].present?
              item = Liquidation.find_by(tag_number: row['Tag Number'], is_active: true)
              inv = Inventory.find_by(tag_number: row['Tag Number'])
              dc_items.push(inv.distribution_center_id) if inv.present?
              if item.blank? || inv.blank?
                error_found = true
                loop_error = true
                if inv.blank?
                  error_row = prepare_error_hash(row, row_number, "Tag #{row['Tag Number']} is not present in our system")
                elsif item.blank?
                  error_row = prepare_error_hash(row, row_number, "Tag #{row['Tag Number']} is present in #{inv.get_current_bucket.class.name}")
                end
                errors_hash[row_number] << error_row
                move_to_next = true
              end
            end
            if dc_items.present?
              if dc_items.uniq.size > 1
                error_found = true
                error_row = prepare_error_hash(row, row_number, "Please Provide Only One Distribution Center Items Only")
                errors_hash[row_number] << error_row
                move_to_next = true
                loop_error = true
              end
            end
            next if loop_error
            liquidation_items = Liquidation.where(tag_number: row["Tag Number"], is_active: true, status: ['Pending Lot Creation', 'Pending RFQ'])
            if liquidation_items.blank?
              error_found = true
              loop_error = true
              error_row = prepare_error_hash(row, row_number, "Tag #{row['Tag Number']} number is in #{Liquidation.where(tag_number: row["Tag Number"], is_active: true).last.status}")
              errors_hash[row_number] << error_row
              move_to_next = true
            end
            next if loop_error
            liquidation_items.each do |liquidation_item|
              if liquidation_item.present? && liquidation_item.liquidation_order_id.nil?
                service_liquidation << liquidation_item.id
                liquidation_item.update_attributes(lot_name: row["Lot Name"], mrp: row["MRP"], floor_price: row["Floor Price"])
                liquidation_item.inventory.update(item_price: row["MRP"])
              else
                error_found = true
                loop_error = true
                error_row = prepare_error_hash(row, row_number, "Tag number is already mapped to Lot")
                errors_hash[row_number] << error_row
                move_to_next = true
              end
            end
          end
        end
        # liquidation order creation starts
        if error_found || errors_hash.values.flatten.present?
          all_error_messages = errors_hash.values.flatten.collect{|h| h[:message].to_s}
          all_error_message_str = all_error_messages.join(',')
          inventory_file_upload.update_columns(status: "Failed", remarks: all_error_message_str) if inventory_file_upload.present?
          return false
        else
          @liquidations = Liquidation.where(id: service_liquidation, liquidation_order_id: nil)
          all_liquidations = @liquidations.reject {|i| i.lot_name.nil?}.group_by{ |c| c.lot_name }
          all_liquidations.each do |lot_name, liquidations|
            lot_mrp = liquidations.inject(0){|sum,x| (sum + x.mrp.to_i) if x.mrp.present? }
            lot_floor_price = liquidations.inject(0){|sum,x| (sum + x.floor_price.to_i)}
            liquidation_order = LiquidationOrder.new(lot_name: lot_name, lot_desc: lot_name, mrp: lot_mrp, floor_price: lot_floor_price, status: lot_status.original_code, status_id: lot_status.id, order_amount: lot_mrp, quantity: liquidations.count, lot_type: lot_type.original_code, lot_type_id: lot_type.id)
            if liquidation_order.save
              liquidation_order_history = LiquidationOrderHistory.create(liquidation_order_id:liquidation_order.id, status: lot_status.original_code, status_id: lot_status.id)
              liquidations.each do |liquidation|
                liquidation_item = liquidation
                if liquidation_item.present?
                  liquidation_item.update(liquidation_order_id: liquidation_order.id, status: new_liquidation_status.original_code, status_id: new_liquidation_status.id, lot_type: lot_type.original_code, lot_type_id: lot_type.id)
                  LiquidationHistory.create(liquidation_id: liquidation_item.id, status_id: new_liquidation_status.id, status: new_liquidation_status.original_code)
                end
              end
              liquidation_order.tags = liquidation_order.liquidations.pluck(:tag_number)
              liquidation_order.details ||= {}
              liquidation_order.details['master_file_id'] = inventory_file_upload_id
              liquidation_order.details['master_lot_file_url'] = inventory_file_upload.inventory_file.url
              liquidation_order.save
            else
              lot_error_found = true
              lot_errors << (liquidation_order.lot_name+":" + liquidation_order.errors.full_messages.flatten.join(","))
            end
          end
        end
        # liquidation order creation ends
        raise ActiveRecord::Rollback if (error_found || lot_error_found)
      end
    rescue Exception => message
      inventory_file_upload.update_columns(status: "Failed", remarks: "Line Number #{i}:"+message.to_s)
    else
      inventory_file_upload.update_columns(status: "Completed")
    ensure
      if error_found && lot_error_found
        all_error_messages = errors_hash.values.flatten.collect{|h| h[:message].to_s}
        all_error_message_str = all_error_messages.join(',')
        inventory_file_upload.update_columns(status: "Failed", remarks: all_error_message_str+','+lot_errors.flatten.join(",")) if inventory_file_upload.present?
        return false
      elsif error_found
        all_error_messages = errors_hash.values.flatten.collect{|h| h[:message].to_s}
        all_error_message_str = all_error_messages.join(',')
        inventory_file_upload.update_columns(status: "Failed", remarks: all_error_message_str) if inventory_file_upload.present?
        return false
      elsif lot_error_found
        inventory_file_upload.update_columns(status: "Failed", remarks: lot_errors.flatten.join(",")) if inventory_file_upload.present?
        return false
      end
    end
  end

  def self.prepare_error_hash(row, rownubmer, message)
    message = "Error In row number (#{rownubmer}) : " + message.to_s
    return {row: row, row_number: rownubmer, message: message}
  end

  def self.check_numeric_price(value)
    numeric_mrp = value.to_i
    (numeric_mrp.to_s == value) && (numeric_mrp > 0)
  end

  def self.import_liquidation_lot(inventory_file_upload_id)
    inventory_lookups = InventoryLookup.active
    mandatory_lookups = InventoryLookup.mandatory
    lookup_params = inventory_lookups.pluck(:original_name)
    available_categories = InventoryLookup.where("original_name ilike (?)", "category%").pluck(:original_name).sort
    lookup_key_city = LookupKey.where(code: 'CITY').last
    all_sl_cities = LookupValue.where(lookup_key_id: lookup_key_city.id).pluck(:original_code, :id).to_h.transform_keys(&:downcase)
    lookup_key_grade = LookupKey.where(code: 'STANDALONE_INVENTORY_GRADE').last
    all_sl_grades = LookupValue.where(lookup_key_id: lookup_key_grade.id).pluck(:original_code)
    inv_status = LookupValue.find_by(code: Rails.application.credentials.liquidation_status_pending_publish_status)
    lot_type = LookupValue.find_by(code: Rails.application.credentials.liquidation_lot_type_competitive_lot)
    lot_status = LookupValue.find_by(code: Rails.application.credentials.lot_status_pending_lot_details)
    distribution_center_city = DistributionCenter.pluck(:city_id, :id).to_h
    category_hash = ClientCategory.where("ancestry is null").group_by(&:name)
    liquidation_pending_status = LookupValue.where(code:Rails.application.credentials.liquidation_pending_status).first
    client_sku_master_hash = ClientSkuMaster.pluck(:client_category_id, :id).to_h
    client_id = Client.first.id
    liquidation_record_ids = Liquidation.pluck(:tag_number, :id).to_h
    liquidation_order_ids = Liquidation.pluck(:tag_number, :liquidation_order_id).to_h
    liquidation_histories = []
    errors_hash = {}
    error_found = false
    lot_details = {}
    lot_images = {}
    lot_categories = {}
    child_category_hash = {}
    ClientCategory.where("ancestry is not null").each do |client_category|
      child_category_hash[client_category.ancestry] ||= {}
      child_category_hash[client_category.ancestry][client_category.name] = client_category
    end
    inventory_file_upload = InventoryFileUpload.includes(:user).where("id = ?", inventory_file_upload_id).first
    data = CSV.parse(inventory_file_upload.inventory_file.read.force_encoding("UTF-8"), {headers: true, external_encoding: "ISO8859-1", internal_encoding: "utf-8"})
    current_user = inventory_file_upload.user
    default_distribution_id = current_user.distribution_centers.first.id rescue nil
    inventories_arr = []
    begin
      quantity = 0
      data.each_with_index do |row, index|
        quantity += row['Quantity'].to_i
      end
      tag_numbers = Inventory.generate_bulk_tag(quantity)
      i = 1
      ActiveRecord::Base.transaction do
        data.each_with_index do |row, index|
          all_params = row.to_h.keys
          i = i+1
          row_number = i

          if row.to_hash.values.any?
            move_to_next = false
            errors_hash.merge!(row_number => [])
            inv_hash = {}
            row_details = {}

            inventory_lookups.each do |il|
              if il.original_name == "Tag Number"
                inv_hash["#{il.name}".to_sym] = row[il.original_name]&.downcase
              elsif il.original_name == "MRP (in INR)"
                if check_numeric_price(row[il.original_name])
                  inv_hash["#{il.name}".to_sym] = row[il.original_name]
                else
                  error_found = true
                  error_row = prepare_error_hash(row, row_number, "#{il.original_name} is Not a Number")
                  errors_hash[row_number] << error_row
                  move_to_next = true
                end
              else
                inv_hash["#{il.name}".to_sym] = row[il.original_name]
              end
            end

            mandatory_lookups.each do |il|
              if row[il.original_name].blank?
                error_found = true
                error_row = prepare_error_hash(row, row_number, "#{il.original_name} is blank")
                errors_hash[row_number] << error_row
                move_to_next = true
              end
            end

            valid_grade = all_sl_grades.include?(inv_hash[:grade])

            if valid_grade.blank?
              error_found = true
              error_row = prepare_error_hash(row, row_number, "Invalid grade")
              errors_hash[row_number] << error_row
              move_to_next = true
            end

            valid_city = all_sl_cities[row['City']&.strip&.downcase]

            if valid_city.nil?
              error_found = true
              error_row = prepare_error_hash(row, row_number, "Invalid city")
              errors_hash[row_number] << error_row
              move_to_next = true
            else
              inv_hash[:distribution_center_id] = default_distribution_id || distribution_center_city[valid_city]
            end

            if row['Lot name'].blank?
              error_found = true
              error_row = prepare_error_hash(row, row_number, "Please enter lot name column")
              errors_hash[row_number] << error_row
              move_to_next = true
            end

            leaf_category = nil
            parent_category = nil
            available_categories.each_with_index do |i,il|
              unless row[i].nil?
                if il==0
                  parent_category = category_hash[row["Category L#{il+1}"]].last
                  leaf_category = parent_category
                else
                  if il==1
                    if parent_category.present?
                      # leaf_category = parent_category.children.where(name: row["Category L#{il+1}"]).last
                      leaf_category = child_category_hash[parent_category.id.to_s][row["Category L#{il+1}"]]
                    end
                  else
                    if leaf_category.present?
                      # leaf_category = leaf_category.children.where(name: row["Category L#{il+1}"]).last
                      key = leaf_category.ancestry.present? ? "#{leaf_category.ancestry}/#{leaf_category.id}" : "#{leaf_category.id}"
                      leaf_category = child_category_hash[key][row["Category L#{il+1}"]]
                    end
                  end
                end
              end
            end

            if parent_category.nil?
              error_found = true
              error_row = prepare_error_hash(row, row_number, "Please enter Category L1 column")
              errors_hash[row_number] << error_row
              move_to_next = true
            else
              lot_categories[row['Lot name']] = (lot_categories[row['Lot name']] || []) << parent_category.name
            end

            if leaf_category.nil?
              error_found = true
              error_row = prepare_error_hash(row, row_number, "Category Mismatch")
              errors_hash[row_number] << error_row
              move_to_next = true
            else
              inv_hash[:client_category_id] = leaf_category&.id
              leaf_category.path.pluck(:name).each.with_index(1) do |category_name, i|
                category_list = "category_l#{i}"
                row_details[category_list] = category_name if category_name.present?
              end
            end

            (all_params-lookup_params).each do |k|
              row_details[k] = row[k] unless row[k].blank?
            end

            inv_hash[:details] = row_details
            inv_hash[:status_id] = inv_status.id
            inv_hash[:status] = inv_status.original_code
            inv_hash[:client_id] = client_id
            inv_hash[:user_id] = current_user.id

            lot_images[row['Lot name']] = (lot_images[row['Lot name']] || []) << row['Image Urls'].gsub("\n", ",").split(',').reject(&:blank?) unless row['Image Urls'].blank?

            if inv_hash[:tag_number].blank?
              (1..inv_hash[:quantity].to_i).each do |q|
                inv_hash[:tag_number] = tag_numbers.pop
                inv_hash[:quantity] = 1
                inventory = Inventory.create(inv_hash)
                # inventories_arr << inventory
                if liquidation_order_ids[inventory.tag_number].blank?
                  if liquidation_record_ids.keys.exclude?(inventory.tag_number)
                    client_sku_master_id = client_sku_master_hash[inventory.client_category_id]
                    liquidation = Liquidation.create_record(inventory, nil, current_user.id, current_user, liquidation_pending_status, client_sku_master_id, false)
                    if liquidation
                      liquidation.update_attributes(floor_price: inventory.details['Benchmark Price'])
                      liquidation_histories << { liquidation_id: liquidation.id , status_id: liquidation_pending_status.try(:id), status: liquidation_pending_status.try(:original_code), created_at: Time.now, updated_at: Time.now, details: {"status_changed_by_user_id" => current_user&.id, "status_changed_by_user_name" => current_user&.full_name }}
                      liquidation_record_ids[inventory.tag_number] = liquidation.id
                    end
                  end
                  lot_details[row['Lot name']] = (lot_details[row['Lot name']] || []) << liquidation_record_ids[inventory.tag_number]
                else
                  error_found = true
                  error_row = prepare_error_hash(row, row_number, "Tag Number already mapped to bundle")
                  errors_hash[row_number] << error_row
                  move_to_next = true
                end
              end
            else
              inv_hash[:quantity] = 1
              inventory = Inventory.where(tag_number: inv_hash[:tag_number]).last
              unless inventory
                inventory = Inventory.create(inv_hash)
                # inventories_arr << inventory
              end
              if liquidation_order_ids[inventory.tag_number].blank?
                inventory.update(inv_hash)
                if liquidation_record_ids.keys.exclude?(inventory.tag_number)
                  client_sku_master_id = client_sku_master_hash[inventory.client_category_id]
                  liquidation = Liquidation.create_record(inventory, nil, current_user.id, current_user, liquidation_pending_status, client_sku_master_id, false)
                  if liquidation
                    liquidation.update_attributes(floor_price: inventory.details['Benchmark Price'])
                    liquidation_histories << { liquidation_id: liquidation.id , status_id: liquidation_pending_status.try(:id), status: liquidation_pending_status.try(:original_code), created_at: Time.now, updated_at: Time.now, details: {"status_changed_by_user_id" => current_user&.id, "status_changed_by_user_name" => current_user&.full_name }}
                    liquidation_record_ids[inventory.tag_number] = liquidation.id
                  end
                end
                lot_details[row['Lot name']] = (lot_details[row['Lot name']] || []) << liquidation_record_ids[inventory.tag_number]
              else
                error_found = true
                error_row = prepare_error_hash(row, row_number, "Tag Number already mapped to bundle")
                errors_hash[row_number] << error_row
                move_to_next = true
              end
            end
          end
        end
        raise ActiveRecord::Rollback if error_found
        # Inventory.import(inventories_arr) if inventories_arr.present?
        LiquidationHistory.insert_all(liquidation_histories) if liquidation_histories.present?

        lot_details.each do |lot_name, liquidation_ids|
          next unless lot_name
          liquidation_ids = liquidation_ids.flatten.compact.uniq
          inventories = Inventory.joins(:liquidation).where('liquidations.id': liquidation_ids).distinct
          lot_mrp = inventories.inject(0){|sum,x| (sum + x.item_price.to_i) if x.item_price.present? }
          floor_price = inventories.inject(0){|sum,x| (sum + x.details['Benchmark Price'].to_i) if x.details['Benchmark Price'].to_i.present? }
          tags = inventories.pluck(:tag_number).compact.uniq
          details = { 'master_lot_file_url' => inventory_file_upload.inventory_file&.url }
          lot_image_urls = lot_images[lot_name].flatten.uniq.compact rescue []
          lot_category = lot_categories[lot_name].compact.uniq.join(' || ') rescue "N/A"
          lot_params = {
            lot: {
              lot_name: lot_name,
              mrp: lot_mrp,
              floor_price: floor_price,
              status:lot_status.original_code,
              status_id: lot_status.id,
              quantity: liquidation_ids&.count,
              lot_type: lot_type.original_code,
              lot_type_id: lot_type.id,
              lot_image_urls: lot_image_urls,
              details: details,
              lot_category: lot_category,
              tags: tags,
              created_by_id: current_user.id,
              distribution_center_id: inventories.first.distribution_center_id
            },
            liquidation_ids: liquidation_ids,
          }
          LiquidationOrder.create_lot(lot_params, current_user)
        end
      end
    rescue Exception => message
      if message.to_s.include?("UTF")
        inventory_file_upload.update(status: "Failed", remarks: "Line Number #{i+1}:"+message.to_s)
      else
        inventory_file_upload.update(status: "Failed", remarks: "Line Number #{i}:"+message.to_s)
      end
    else
      inventory_file_upload.update(status: "Completed")
    ensure
      if error_found
        all_error_messages = errors_hash.values.flatten.collect do |h| h[:message].to_s end
        all_error_message_str = all_error_messages.join(',')
        inventory_file_upload.update(status: "Failed", remarks: all_error_message_str) if inventory_file_upload.present?
        return false
      end
    end
  end

  def self.import_file_upload_job
    where(status: "Uploading").order(:created_at).limit(5).each do |import_file|
      next unless import_file.reload.status == 'Uploading'
      begin
        import_file.update(status: 'Import Started')
        import_liquidation_lot(import_file)
      rescue => message
        import_file.update(status: 'Failed', remarks: message.to_s)
      end
    end
  end
end
