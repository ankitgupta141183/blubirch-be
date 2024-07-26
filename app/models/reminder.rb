class Reminder < ApplicationRecord

  acts_as_paranoid
  
	belongs_to :client_category, optional: true
	belongs_to :client_sku_master, class_name: 'ClientSkuMaster', foreign_key: 'sku_master_id', optional: true
	belongs_to :customer_return_reason

	include Filterable
  scope :filter_by_client_category_id, -> (client_category_id) { where("client_category_id in (?)", client_category_id)}
  scope :filter_by_sku_master_id, -> (sku_master_id) { where("sku_master_id in (?)", sku_master_id)}
  scope :filter_by_customer_return_reason_id, -> (customer_return_reason_id) { where("customer_return_reason_id in (?)", customer_return_reason_id)}  
  scope :filter_by_status_id, -> (status_id) { where("status_id in (?)", status_id)}  
  scope :filter_by_approval_required, -> (approval_required) { where("approval_required ilike ?", "%#{approval_required}%")}

  def self.import(file)
    #begin
      i = 1
      ActiveRecord::Base.transaction do
        reminders = CSV.read(file.path, headers: true)
        reminders.each do |row|
          i = i+1
          h = Hash.new
          details = Hash.new
          row.to_hash.each do |k,v|
            if k.starts_with?("Escalation")
              details[k.split(" ").first] = Hash.new unless details.key?(k.split(" ").first)
              details[k.split(" ").first][k.split(" ")[1].try(:strip)] = v
            elsif k.starts_with?("Reminder") || k == "Approval To" || k == "Copy To"
              details[k] = v
            end
          end
          sku_master_id = ClientSkuMaster.where(code: row[0].try(:strip)).last
          h["status_id"] = LookupValue.where(original_code: row[1].try(:strip)).last.id
          h["client_category_id"] = sku_master_id.client_category_id
          h["customer_return_reason_id"] = CustomerReturnReason.where(name: row[2].try(:strip)).last.id
          h["sku_master_id"] = sku_master_id.id
          h["approval_required"] = row[3].try(:strip)
          h["details"] = details
          reminder = Reminder.where(sku_master_id: sku_master_id.id).last
          if reminder.present?
            reminder.update_attributes(h)
          else
            reminder = Reminder.new(h)
            reminder.save
          end
        end
      end
    #rescue Exception => message
      #return "Line Number #{i}:"+message.to_s
    #end
  end

  def self.parse_template (template, attrs={})
    result = template
    attrs.each { |field, value| result.gsub!("{{#{field}}}", value) }
    result.gsub!(/\{\{\.w+\}\}/, '')
    return result
  end

end
