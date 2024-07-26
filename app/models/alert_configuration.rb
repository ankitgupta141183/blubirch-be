class AlertConfiguration < ApplicationRecord
    acts_as_paranoid
    has_many :alert_inventories


    DISPOSITION_BUCKET = {"Liquidation" => "Liquidation", "Repair" => "Repair","Replacement" => "Replacement","Insurance" => "Insurance","Brand Call-Log" => "BrandCallLog","Restock" => "Restock","Pending Transfer Out" => "Markdown" ,"E-Waste" => "EWaste", "Pending Disposition" =>"PendingDisposition", "RTV" => "VendorReturn", "Dispatch" => "WarehouseOrder", "Rental" => "Rental", "Saleable" => "Saleable", "Cannibalization" => "Cannibalization", "Capital Assets" => "CapitalAsset", "Demo" => "Demo", "Production" => "Production" }


    def self.underscore(str)
        str.gsub(/::/, '/').
        gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
        gsub(/([a-z\d])([A-Z])/,'\1_\2').
        tr("-", "_").
        downcase
     end

    def self.check_for_errors(errors_hash,row_number,row)

      
      error2 = ""
      flag = 1 
      error_found = false

      disposition = row["Disposition"]
      if disposition.present? && !AlertConfiguration::DISPOSITION_BUCKET[disposition].present?
        error2 = "Disposition does not exist in database"
        error_found = true
        error_row = prepare_error_hash(row, row_number, error2)
        errors_hash[row_number] << error_row
      end

      disposition_table_name = AlertConfiguration::DISPOSITION_BUCKET[disposition] if disposition.present?

      if disposition.present? && AlertConfiguration::DISPOSITION_BUCKET[disposition].present?
        lookup_key = Inventory::STATUS_LOOKUP_KEY_NAMES[disposition]
        status_arr = LookupKey.find_by(name: lookup_key).lookup_values.collect(&:original_code)
        if !status_arr.include?(row["Stage"])

            error2 = "Invalid Status for #{row['Disposition']}"
            error_found = true
            error_row = prepare_error_hash(row, row_number, error2)
            errors_hash[row_number] << error_row
        end
      end

      if !row["Disposition"].present?
        error2 = "Disposition cannot be blank"
        error_found = true
        error_row = prepare_error_hash(row, row_number, error2)
        errors_hash[row_number] << error_row
      end
      if !row["Criticality"].present?
        error2 = "Criticality cannot be blank"
        error_found = true
        error_row = prepare_error_hash(row, row_number, error2)
        errors_hash[row_number] << error_row
      end
      if !row["Properties"].present?
        error2 = "Properties cannot be blank"
        error_found = true
        error_row = prepare_error_hash(row, row_number, error2)
        errors_hash[row_number] << error_row
      end
      if !row["Rank"].present?
        error2 = "Rank cannot be blank"
        error_found = true
        error_row = prepare_error_hash(row, row_number, error2)
        errors_hash[row_number] << error_row
      end
      if !row["Stage"].present?
        error2 = "Stage cannot be blank"
        error_found = true
        error_row = prepare_error_hash(row, row_number, error2)
        errors_hash[row_number] << error_row
      end
      

      return error_found , errors_hash



    end

    def self.prepare_error_hash(row, rownubmer, message)
      message = "Error In row number (#{rownubmer}) : " + message.to_s
      return {row: row, row_number: rownubmer, message: message}
    end

    def self.import(master_file_upload,dc_id)    

        errors_hash = Hash.new(nil)
        error_found = false
      begin
        master_file_upload = MasterFileUpload.where("id = ?", master_file_upload).first
        client_id = master_file_upload.client_id if master_file_upload.present?
        AlertConfiguration.transaction do
          if master_file_upload.present?
            temp_file = open(master_file_upload.master_file.url)
            file = File.new(temp_file)
            data = CSV.read(file.path, {headers: true, encoding: "iso-8859-1:utf-8"})         
          else
            file = File.new("#{Rails.root}/public/master_files/alert_configuration_rules.csv") #if master_file_upload.nil?
            data = CSV.read(file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
          end
          headers = data.headers

          
          alert_array = []
          alert_hash = {}
          criticality_rank_hash = {}



          data.each_with_index do |row, index|

            row_number = index + 1
            errors_hash.merge!(row_number => [])
            
            move_to_next = false      
            
            move_to_next , errors_hash = AlertConfiguration.check_for_errors(errors_hash,row_number,row)

            if move_to_next
              error_found = true
            end

            next if move_to_next

            attr_hash = {}
            attr_detail_hash = {}
            
            # Code for fetching of catgory ids for uniq test andd grading rule starts
            alert_hash["disposition"] = row["Disposition"]  if row["Disposition"].present?
            alert_hash["status"] = row["Stage"]
             
            ac = AlertConfiguration.where(disposition: alert_hash["disposition"], status: alert_hash["status"],distribution_center_id: dc_id).first_or_create(disposition: alert_hash["disposition"], status: alert_hash["status"],distribution_center_id:dc_id)
            if !ac.details.present?
                ac.details = {}
                ac.details["limits"]=[]
                ac.details["limits_attr"] = {}
                ac.details["criticality_hash"] = {}

            end

            row["Properties"].split('/').each do |p|
                attr_hash["#{p}"] = row["Limit-#{p}"]
                attr_detail_hash["#{p}"] = row["#{p}-Attr"]
            end

            ac.details["limits"][row["Rank"].to_i] = attr_hash
            ac.details["limits_attr"] = attr_detail_hash
            ac.details["criticality_hash"]["#{row["Rank"]}"] = row["Criticality"]

            ac.save        

            # Code for End Row Ends

          end # data loop ends   
        end # transaction ends
      ensure
        if error_found
          all_error_messages = errors_hash.values.flatten.collect do |h| h[:message].to_s end
          all_error_message_str = all_error_messages.join(',')
          
          puts "--------hello----#{master_file_upload}-----"
          master_file_upload.update(status: "Halted", remarks: all_error_message_str) if master_file_upload.present?
          return false
        else
          all_error_messages = errors_hash.values.flatten.collect do |h| h[:message].to_s end
          all_error_message_str = all_error_messages.join(',')
         
          master_file_upload.update(status: "Completed") if master_file_upload.present?
         
          return true
        end
      end
    end



    def self.check_for_inventories
        inventories_arr = []

        AlertConfiguration.all.each do |ac|
          limits_attr = ac.details["limits_attr"]
          inventories_arr = []
          alert_inventories = Inventory.where("inventories.distribution_center_id = ? AND details->>'status' = ? AND details->>'disposition'= ? ",ac.distribution_center_id,ac.status,ac.disposition)
          #alert_inventories = Inventory.where(id:27) 
          alert_inventories.each do |inv|
            flag = 0
            ac.details["limits"].each_with_index do |limit,index|
              str = ""
              next if !limit.present?
              
              limit.each do |key ,value|
                if value == "MAX"
                  flag = -1
                  break
                end
                if key == "Aging"
                  str = str + "(inv.#{limits_attr[key]}.to_i < #{(Time.now + value.to_i.days).to_i})&&"
                else
                  str = str + "(inv.details['#{limits_attr[key]}'] < #{value.to_i})&&"
                end      

              end
              if eval(str.delete_suffix('&&')) || flag == -1
                if inventories_arr[index-1].present?
                  inventories_arr[index-1].push(inv.id)
                else
                  inventories_arr[index-1] = []
                  inventories_arr[index-1].push(inv.id)
                end
                break
              end
              
            end

            

          end
          inventories_arr.each_with_index do |inv_arr,index|
            if inv_arr.present?
                inv_arr.each do |inv|
                    i=Inventory.find(inv)
                    i.details["criticality"]=ac.details["criticality_hash"]["#{index+1}"] rescue nil
                    i.save
                    AlertInventory.create(inventory_id: inv,alert_configuration_id: ac.id)
                end
            end
          end
        end     
    end


    def self.check_for_bucket_records
      begin
        task_manager = TaskManager.create_task('AlertConfiguration.check_for_bucket_records')
        bucket_record_hash = {}
        inventories_arr = []
        account_setting = AccountSetting.first

        AlertConfiguration.all.each do |ac|
          limits_attr = ac.details["limits_attr"]
          inventories_arr = []

          status = if ac.disposition == 'Brand Call-Log'
            st = ac.status.underscore.split.join('_')
            ['pending_information', 'pending_bcl_ticket', 'pending_inspection', 'pending_decision', 'pending_disposition', 'closed'].include?(st) ? st : 'Not Defined'
          else
            ac.status
          end

          # on the bases of dispotion the limits are set on the account setting criticality_limits
          # criticality_limits = {"Repair" => [{"Aging"=>"4"}, {"Aging"=>"6"}, {"Aging"=>"MAX"}], "Brand Call-Log" => [{"Aging"=>"4"}, {"Aging"=>"6"}, {"Aging"=>"MAX"}], "Insurance" => [{"Aging"=>"4"}, {"Aging"=>"6"}, {"Aging"=>"MAX"}], "Replacement" => [{"Aging"=>"4"}, {"Aging"=>"6"}, {"Aging"=>"MAX"}], "E-Waste" => [{"Aging"=>"4"}, {"Aging"=>"6"}, {"Aging"=>"MAX"}], "Pending Disposition" => [{"Aging"=>"4"}, {"Aging"=>"6"}, {"Aging"=>"MAX"}], "Cannibalization" => [{"Aging"=>"4"}, {"Aging"=>"6"}, {"Aging"=>"MAX"}], "Liquidation" => [{"Aging"=>"4"}, {"Aging"=>"6"}, {"Aging"=>"MAX"}], "Pending Transfer Out" => [{"Aging"=>"4"}, {"Aging"=>"6"}, {"Aging"=>"MAX"}], "RTV" => [{"Aging"=>"4"}, {"Aging"=>"6"}, {"Aging"=>"MAX"}], "Default" => [{"Aging"=>"4"}, {"Aging"=>"6"}, {"Aging"=>"MAX"}]}

          next if status == 'Not Defined'
          bucket_inventories_str = "#{AlertConfiguration::DISPOSITION_BUCKET[ac.disposition]}.where(status:'#{status}',is_active:#{true})"
          bucket_inventories = eval(bucket_inventories_str) rescue []
          bucket_inventories.each do |inv|
            flag = 0
            account_setting.criticality_limits[ac.disposition].each_with_index do |limit,index|
              str = ""
              next if !limit.present?
              key = "Aging"

              if limit[key] != "MAX"
                status_change_date = eval("inv.#{AlertConfiguration.underscore(AlertConfiguration::DISPOSITION_BUCKET[ac.disposition])}_histories.find_by_status_id(#{inv.status_id}).created_at") rescue nil
                if status_change_date.present?
                  #str = "((Time.now.to_i - status_change_date.to_i)/86400 <= #{limit[key].to_i})"
                  str = "((Date.today.to_date - status_change_date.to_date).to_i <= #{limit[key].to_i})"
                else                        
                  #str = "((Time.now.to_i - inv.#{limits_attr[key]}.to_i)/86400 <= #{limit[key].to_i})"
                  str = "((Date.today.to_date - inv.#{limits_attr[key]}.to_date) <= #{limit[key].to_i})"
                end
              else
                flag = -1
              end

              if eval(str) || flag == -1
                if inventories_arr[index-1].present?
                  inventories_arr[index-1].push(inv.id)
                else
                  inventories_arr[index-1] = []
                  inventories_arr[index-1].push(inv.id)
                end
                break
              end
            end
          end

          inventories_arr.each_with_index do |inv_arr,index|
            if inv_arr.present?
              inv_arr.each do |inv|
                i = eval("#{AlertConfiguration::DISPOSITION_BUCKET[ac.disposition]}.find_by(id: #{inv})")
                next if i.nil? || i.inventory.nil?
                i.details["criticality"]=ac.details["criticality_hash"]["#{index+1}"] rescue nil
                i.save(validate: false) rescue nil
              end
            end
          end
        end
        task_manager.complete_task
      rescue => exception
        task_manager.complete_task(exception)
      end
    end

  def self.rename_disposition_masrdown
    AlertConfiguration.where(disposition: 'Markdown').each do |ac|
      ac.disposition = 'Pending Transfer Out'
      if ac.status == 'Pending Markdown Destination'
        ac.status = 'Pending Transfer Out Destination'
      elsif ac.status == 'Pending Markdown Dispatch'
        ac.status = 'Pending Transfer Out Dispatch'
      elsif ac.status == ''
        ac.status = 'Pending Transfer Out Dispatch Complete'
      end
      ac.save
    end
  end

  def self.update_disposition_dashboard_count
    begin
      task_manager = TaskManager.create_task('AlertConfiguration.update_disposition_dashboard_count')
      distribution_centers = DistributionCenter.where("site_category in (?)", ["R", "B"])
      distribution_centers.each do |distribution_center|
        result = Hash.new(0)
        ['Central Admin', 'Default User'].each do |user_type|
          AlertConfiguration::DISPOSITION_BUCKET.each do |key, value|
            result[key.parameterize.underscore] = {}
            if key =='Brand Call-Log'
              status = []
              if user_type == 'Central Admin'
                brand_call_logs = "#{value}".constantize.includes(:inventory, :distribution_center).where("brand_call_logs.distribution_center_id = ? AND brand_call_logs.is_active = ? AND (brand_call_logs.status IN (?) OR (brand_call_logs.status = ? AND brand_call_logs.assigned_disposition IS NOT NULL))", distribution_center.id, true, [1,2,3,4], 5).references(:inventories)
                low_str = brand_call_logs.where("brand_call_logs.details->>'criticality' = ?", 'Low')
                med_str = brand_call_logs.where("brand_call_logs.details->>'criticality' = ?", 'Medium')
                high_str = brand_call_logs.where("brand_call_logs.details->>'criticality' = ?", 'High')
              else
                brand_call_logs = "#{value}".constantize.includes(:inventory, :distribution_center).where("brand_call_logs.distribution_center_id = ? AND brand_call_logs.is_active = ? AND (brand_call_logs.status IN (?) OR (brand_call_logs.status = ? AND brand_call_logs.assigned_disposition IS NULL))", distribution_center.id, true, [1,2,3,4], 5).references(:inventories)
                low_str = brand_call_logs.where("brand_call_logs.details->>'criticality' = ?", 'Low')
                med_str = brand_call_logs.where("brand_call_logs.details->>'criticality' = ?", 'Medium')
                high_str = brand_call_logs.where("brand_call_logs.details->>'criticality' = ?", 'High')
              end
            elsif key =='RTV'
              low_str = "#{value}".constantize.joins(:inventory).where("vendor_returns.status = 'Pending Dispatch' AND vendor_returns.details->>'criticality' = ? AND vendor_returns.distribution_center_id = ? AND vendor_returns.is_active = ?", 'Low', distribution_center.id, true).references(:inventories) + "#{value}".constantize.joins([vendor_return_order: [warehouse_orders: :warehouse_order_items]]).where("warehouse_order_items.tab_status in (1,2,3) AND vendor_returns.is_active = true AND vendor_returns.details->>'criticality' = 'Low' AND warehouse_orders.distribution_center_id = ?", distribution_center.id).uniq
              med_str = "#{value}".constantize.joins(:inventory).where("vendor_returns.status = 'Pending Dispatch' AND vendor_returns.details->>'criticality' = ? AND vendor_returns.distribution_center_id = ? AND vendor_returns.is_active = ?", 'Medium', distribution_center.id, true).references(:inventories) + "#{value}".constantize.joins([vendor_return_order: [warehouse_orders: :warehouse_order_items]]).where("warehouse_order_items.tab_status in (1,2,3) AND vendor_returns.is_active = true AND vendor_returns.details->>'criticality' = 'Medium' AND warehouse_orders.distribution_center_id = ?", distribution_center.id).uniq
              high_str = "#{value}".constantize.joins(:inventory).where("vendor_returns.status = 'Pending Dispatch' AND vendor_returns.details->>'criticality' = ? AND vendor_returns.distribution_center_id = ? AND vendor_returns.is_active = ?", 'High', distribution_center.id, true).references(:inventories) + "#{value}".constantize.joins([vendor_return_order: [warehouse_orders: :warehouse_order_items]]).where("warehouse_order_items.tab_status in (1,2,3) AND vendor_returns.is_active = true AND vendor_returns.details->>'criticality' = 'High' AND warehouse_orders.distribution_center_id = ?", distribution_center.id).uniq
            elsif key =='Insurance'
              status = ['Pending Insurance Submission', 'Pending Insurance Call Log', 'Pending Insurance Inspection', 'Pending Insurance Approval', 'Pending Insurance Dispatch', 'Pending Insurance Disposition']
              low_str = "#{value}".constantize.includes(:inventory, :distribution_center).where("insurances.details->>'criticality' = ? and inventories.is_putaway_inwarded IS NOT false and insurances.distribution_center_id = ? and insurances.is_active = ? and insurances.status in (?)", 'Low', distribution_center.id, true, status).references(:inventories)
              med_str = "#{value}".constantize.includes(:inventory, :distribution_center).where("insurances.details->>'criticality' = ? and inventories.is_putaway_inwarded IS NOT false and insurances.distribution_center_id = ? and insurances.is_active = ? and insurances.status in (?)", 'Medium', distribution_center.id, true, status).references(:inventories)
              high_str = "#{value}".constantize.includes(:inventory, :distribution_center).where("insurances.details->>'criticality' = ? and inventories.is_putaway_inwarded IS NOT false and insurances.distribution_center_id = ? and insurances.is_active = ? and insurances.status in (?)", 'High', distribution_center.id, true, status).references(:inventories)
            elsif key =='Replacement'
              status = ['Pending Replacement Approved', 'Pending Replacement Disposition', 'Pending Redeployment']
              low_str = "#{value}".constantize.includes(:inventory, :distribution_center).where("replacements.details->>'criticality' = ? and inventories.is_putaway_inwarded IS NOT false and replacements.distribution_center_id = ? and replacements.is_active = ? and replacements.status in (?)", 'Low', distribution_center.id, true, status).references(:inventories)
              med_str = "#{value}".constantize.includes(:inventory, :distribution_center).where("replacements.details->>'criticality' = ? and inventories.is_putaway_inwarded IS NOT false and replacements.distribution_center_id = ? and replacements.is_active = ? and replacements.status in (?)", 'Medium', distribution_center.id, true, status).references(:inventories)
              high_str = "#{value}".constantize.includes(:inventory, :distribution_center).where("replacements.details->>'criticality' = ? and inventories.is_putaway_inwarded IS NOT false and replacements.distribution_center_id = ? and replacements.is_active = ? and replacements.status in (?)", 'High', distribution_center.id, true, status).references(:inventories)
            elsif key =='Repair'
              status = ['Pending Repair Initiation', 'Pending Repair Estimate', 'Pending Repair Quotation', 'Pending Repair Approval', 'Pending Repair', 'Pending Repair Completion', 'Pending Repair Grade', 'Pending Repair Disposition', 'Pending Redeployment']
              low_str = "#{value}".constantize.includes(:inventory, :distribution_center).where("repairs.details->>'criticality' = ? and inventories.is_putaway_inwarded IS NOT false and repairs.distribution_center_id = ? and repairs.is_active = ? and repairs.status in (?)", 'Low', distribution_center.id, true, status).references(:inventories)
              med_str = "#{value}".constantize.includes(:inventory, :distribution_center).where("repairs.details->>'criticality' = ? and inventories.is_putaway_inwarded IS NOT false and repairs.distribution_center_id = ? and repairs.is_active = ? and repairs.status in (?)", 'Medium', distribution_center.id, true, status).references(:inventories)
              high_str = "#{value}".constantize.includes(:inventory, :distribution_center).where("repairs.details->>'criticality' = ? and inventories.is_putaway_inwarded IS NOT false and repairs.distribution_center_id = ? and repairs.is_active = ? and repairs.status in (?)", 'High', distribution_center.id, true, status).references(:inventories)
            elsif key =='Liquidation'
              status = ['Pending Liquidation', 'Pending RFQ', 'Pending Publish', 'Inprogress', 'Decision Pending']
              low_str = "#{value}".constantize.includes(:inventory, :distribution_center).where("liquidations.details->>'criticality' = ? and inventories.is_putaway_inwarded IS NOT false and liquidations.distribution_center_id = ? and liquidations.is_active = ? and liquidations.status in (?)", 'Low', distribution_center.id, true, status).references(:inventories)
              med_str = "#{value}".constantize.includes(:inventory, :distribution_center).where("liquidations.details->>'criticality' = ? and inventories.is_putaway_inwarded IS NOT false and liquidations.distribution_center_id = ? and liquidations.is_active = ? and liquidations.status in (?)", 'Medium', distribution_center.id, true, status).references(:inventories)
              high_str = "#{value}".constantize.includes(:inventory, :distribution_center).where("liquidations.details->>'criticality' = ? and inventories.is_putaway_inwarded IS NOT false and liquidations.distribution_center_id = ? and liquidations.is_active = ? and liquidations.status in (?)", 'High', distribution_center.id, true, status).references(:inventories)
            elsif key =='Restock'
              status = []
              low_str = "#{value}".constantize.includes(:inventory, :distribution_center).where("restocks.details->>'criticality' = ? and inventories.is_putaway_inwarded IS NOT false and restocks.distribution_center_id = ? and restocks.is_active = ? and restocks.status in (?)", 'Low', distribution_center.id, true, status).references(:inventories)
              med_str = "#{value}".constantize.includes(:inventory, :distribution_center).where("restocks.details->>'criticality' = ? and inventories.is_putaway_inwarded IS NOT false and restocks.distribution_center_id = ? and restocks.is_active = ? and restocks.status in (?)", 'Medium', distribution_center.id, true, status).references(:inventories)
              high_str = "#{value}".constantize.includes(:inventory, :distribution_center).where("restocks.details->>'criticality' = ? and inventories.is_putaway_inwarded IS NOT false and restocks.distribution_center_id = ? and restocks.is_active = ? and restocks.status in (?)", 'High', distribution_center.id, true, status).references(:inventories)
            elsif key =='Dispatch'
              low_str = "#{value}".constantize.includes(:distribution_center).where("distribution_center_id = ? and total_quantity != 0", distribution_center.id)
              med_str = "#{value}".constantize.includes(:distribution_center).where("distribution_center_id = ? and total_quantity != 0", distribution_center.id)
              high_str = "#{value}".constantize.includes(:distribution_center).where("distribution_center_id = ? and total_quantity != 0", distribution_center.id)
            elsif key =='Rental'
              low_str = "#{value}".constantize.includes(:distribution_center).where("distribution_center_id = ? AND rentals.details->>'criticality' = ?", distribution_center.id, 'Low')
              med_str = "#{value}".constantize.includes(:distribution_center).where("distribution_center_id = ? AND rentals.details->>'criticality' = ?", distribution_center.id, 'Medium')
              high_str = "#{value}".constantize.includes(:distribution_center).where("distribution_center_id = ? AND rentals.details->>'criticality' = ?", distribution_center.id, 'High')
            elsif key =='Saleable'
              low_str = "#{value}".constantize.includes(:distribution_center).where("distribution_center_id = ? AND saleables.details->>'criticality' = ?", distribution_center.id, 'Low')
              med_str = "#{value}".constantize.includes(:distribution_center).where("distribution_center_id = ? AND saleables.details->>'criticality' = ?", distribution_center.id, 'Medium')
              high_str = "#{value}".constantize.includes(:distribution_center).where("distribution_center_id = ? AND saleables.details->>'criticality' = ?", distribution_center.id, 'High')
            elsif key =='Cannibalization'
              status = ["To Be Cannibalized", "Work In Progress", "Cannibalized"]
              low_str = "#{value}".constantize.includes(:distribution_center).where("distribution_center_id = ? AND cannibalizations.details->>'criticality' = ? AND cannibalizations.status IN (?)", distribution_center.id, 'Low', status)
              med_str = "#{value}".constantize.includes(:distribution_center).where("distribution_center_id = ? AND cannibalizations.details->>'criticality' = ? AND cannibalizations.status IN (?)", distribution_center.id, 'Medium', status)
              high_str = "#{value}".constantize.includes(:distribution_center).where("distribution_center_id = ? AND cannibalizations.details->>'criticality' = ? AND cannibalizations.status IN (?)", distribution_center.id, 'High', status)
            elsif key =='Capital Assets'
              low_str = "#{value}".constantize.includes(:distribution_center).where("distribution_center_id = ? AND capital_assets.details->>'criticality' = ?", distribution_center.id, 'Low')
              med_str = "#{value}".constantize.includes(:distribution_center).where("distribution_center_id = ? AND capital_assets.details->>'criticality' = ?", distribution_center.id, 'Medium')
              high_str = "#{value}".constantize.includes(:distribution_center).where("distribution_center_id = ? AND capital_assets.details->>'criticality' = ?", distribution_center.id, 'High')
            elsif key =='Demo'
              low_str = "#{value}".constantize.includes(:distribution_center).where("distribution_center_id = ? AND demos.details->>'criticality' = ? AND demos.is_active = ?", distribution_center.id, 'Low', true)
              med_str = "#{value}".constantize.includes(:distribution_center).where("distribution_center_id = ? AND demos.details->>'criticality' = ? AND demos.is_active = ?", distribution_center.id, 'Medium', true)
              high_str = "#{value}".constantize.includes(:distribution_center).where("distribution_center_id = ? AND demos.details->>'criticality' = ? AND demos.is_active = ?", distribution_center.id, 'High', true)
            elsif key == 'Production'
              status = ["Production Inventory", "Work In Progress", "Finished Or Semi Finished Goods"]
              productions = "#{value}".constantize.includes(:distribution_center).where("distribution_center_id = ? AND productions.is_active = ? AND productions.status IN (?)", distribution_center.id, true, status)
              low_str, med_str, high_str = ['Low', 'Medium', 'High'].map{|x| productions.where("details->>'criticality' = ?", x)}
            else
              low_str = "#{value}".constantize.includes(:inventory, :distribution_center).where("#{value.tableize}.details->>'criticality' = ? and inventories.is_putaway_inwarded IS NOT false and #{value.tableize}.distribution_center_id = ? and #{value.tableize}.is_active = ?", 'Low', distribution_center.id, true).references(:inventories)
              med_str = "#{value}".constantize.includes(:inventory, :distribution_center).where("#{value.tableize}.details->>'criticality' = ? and inventories.is_putaway_inwarded IS NOT false and #{value.tableize}.distribution_center_id = ? and #{value.tableize}.is_active = ?", 'Medium', distribution_center.id, true).references(:inventories)
              high_str = "#{value}".constantize.includes(:inventory, :distribution_center).where("#{value.tableize}.details->>'criticality' = ? and inventories.is_putaway_inwarded IS NOT false and #{value.tableize}.distribution_center_id = ? and #{value.tableize}.is_active = ?", 'High', distribution_center.id, true).references(:inventories)
            end
            result[key.parameterize.underscore] = {'low': low_str.size , 'medium': med_str.size , 'high': high_str.size }
          end
          bucket_information = BucketInformation.where(distribution_center_id: distribution_center.id, distribution_center_code: distribution_center.code, info_type: "Disposition Status #{user_type}").last 
          if bucket_information.present?
            bucket_information.update(distribution_center_id: distribution_center.id, distribution_center_code: distribution_center.code, bucket_status: result)
          else
            BucketInformation.create(distribution_center_id: distribution_center.id, distribution_center_code: distribution_center.code, bucket_status: result, info_type: "Disposition Status #{user_type}") 
          end
        end
      end
      task_manager.complete_task
    rescue => exception
      task_manager.complete_task(exception)
    end
  end

  def self.update_inventory_dahsboard_count
    begin
      task_manager = TaskManager.create_task('AlertConfiguration.update_inventory_dahsboard_count')
      distribution_centers = DistributionCenter.where("site_category in (?)", ["R", "B"])
      distribution_centers.each do |distribution_center|
        ['Central Admin', 'Default User'].each do |user_type|
          result = Hash.new(0)
          AlertConfiguration::DISPOSITION_BUCKET.each do |key, value|
            result[key] = {}
            # Reverse Inventory
            Inventory::STATUS_LOOKUP_KEY_NAMES.each do |lookup_name_key, lookup_name_value|
              if lookup_name_key == key
                LookupKey.find_by(name: lookup_name_value).lookup_values.each do |lv|
                  if lookup_name_value == "ORDER_STATUS_WAREHOUSE"
                    warehouse_orders = "#{value}".constantize.includes(:warehouse_order_items).where("distribution_center_id = ? and total_quantity != ? and status_id = ?", distribution_center.id, 0, lv.id)
                    inventories = warehouse_orders.collect(&:warehouse_order_items).size
                  elsif lookup_name_value == "VENDOR_RETURN_STATUS" && lv.original_code == "Pending Settlement"
                    inventories = WarehouseOrderItem.joins(:warehouse_order).includes(:inventory, :warehouse_order).where("tab_status in (?) AND warehouse_orders.orderable_type = 'VendorReturnOrder' AND warehouse_orders.distribution_center_id = ?", [ 1, 2, 3 ], distribution_center.id)
                  elsif lookup_name_value == "BRAND_CALL_LOG_STATUS"
                    if lv.original_code == 'Pending Disposition'
                      if user_type == 'Central Admin'
                        inventories = "#{value}".constantize.where("distribution_center_id = ? and is_active = ? and status = ?", distribution_center.id, true, BrandCallLog.statuses[lv.original_code.gsub(' ', '_').underscore.to_sym]).where.not(assigned_disposition: nil)
                      else
                        inventories = "#{value}".constantize.where("distribution_center_id = ? and is_active = ? and status = ?", distribution_center.id, true, BrandCallLog.statuses[lv.original_code.gsub(' ', '_').underscore.to_sym]).where(assigned_disposition: nil)
                      end
                    else
                      inventories = "#{value}".constantize.where("distribution_center_id = ? and is_active = ? and status = ?", distribution_center.id, true, BrandCallLog.statuses[lv.original_code.gsub(' ', '_').underscore.to_sym])
                    end
                  elsif lookup_name_value == "INSURANCE_STATUS"
                    inventories = "#{value}".constantize.where("distribution_center_id = ? and is_active = ? and insurance_status = ?", distribution_center.id, true, Insurance.insurance_statuses[lv.original_code.gsub(' ', '_').underscore.to_sym])
                  else
                    inventories = "#{value}".constantize.where("distribution_center_id = ? and is_active = ? and status = ?", distribution_center.id, true, lv.original_code)
                  end
                  result[key][lv.original_code.parameterize.underscore] = inventories.size
                end
              end
            end
            # Forward inventorties
            ForwardInventory::STATUS_LOOKUP_KEY_NAMES.each do |lookup_name_key, lookup_name_value|
              if lookup_name_key == key
                LookupKey.find_by(name: lookup_name_value).lookup_values.each do |lv|
                  inventories = "#{value}".constantize.where("distribution_center_id = ? and is_active = ? and status = ?", distribution_center.id, true, lv.original_code)
                  result[key][lv.original_code.parameterize.underscore] = inventories.size
                end
              end
            end
          end
          dispatch_count = {}
          # dispatch_items = WarehouseOrderItem.joins(:inventory, :warehouse_order).where("inventories.distribution_center_id IN (?) AND item_status = 1", distribution_center.id)
          # Moving the conditions to warehouse_order_items for both reverse and forward inventory fetching
          # dispatch_items = WarehouseOrderItem.joins(:inventory, :warehouse_order).where("inventories.distribution_center_id IN (?) AND item_status = 1", ids)
          reverse_dispatch_items = WarehouseOrderItem.joins(:inventory, :warehouse_order).where("inventories.distribution_center_id IN (?) AND item_status = 1", distribution_center.id)
          forward_dispatch_items = WarehouseOrderItem.joins(:forward_inventory, :warehouse_order).where("forward_inventories.distribution_center_id IN (?) AND item_status = 1", distribution_center.id)
          dispatch_items = if reverse_dispatch_items.present? && forward_dispatch_items.present? 
            reverse_dispatch_items.union(forward_dispatch_items)
          elsif forward_dispatch_items.present? 
            forward_dispatch_items
          else
            reverse_dispatch_items
          end
          WarehouseOrderItem.tab_statuses.each do |status, val|
            if status == "pending_dispatch"
              box_ids = DispatchBox.status_pending.pluck(:id)
              dispatch_count[status] = dispatch_items.where(tab_status: val, dispatch_box_id: box_ids).count
            else
              dispatch_count[status] = dispatch_items.where(tab_status: val).count
            end
          end
          result["Dispatch"] = dispatch_count
          bucket_information = BucketInformation.where(distribution_center_id: distribution_center.id, distribution_center_code: distribution_center.code, info_type: "Inventory Status #{user_type}").last 
          if bucket_information.present?
            bucket_information.update(distribution_center_id: distribution_center.id, distribution_center_code: distribution_center.code, bucket_status: result)
          else
            BucketInformation.create(distribution_center_id: distribution_center.id, distribution_center_code: distribution_center.code, bucket_status: result, info_type: "Inventory Status #{user_type}") 
          end
        end
      end
      task_manager.complete_task
    rescue => exception
      task_manager.complete_task(exception)
    end
  end
end
