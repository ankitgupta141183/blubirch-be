class LookupValue < ApplicationRecord
  
  has_logidze
  acts_as_paranoid
  has_ancestry

  validates :code, :original_code, presence: true


  # filter logic starts
  include Filterable
  scope :filter_by_lookup_key_id, -> (lookup_key_id) { where lookup_key_id: lookup_key_id }
  scope :filter_by_code, -> (code) { where("code ilike ?", "%#{code}%") }
  scope :filter_by_ancestry, -> (ancestry) { where("id in (?)", where("id in (?)", ancestry).collect(&:children).flatten.collect(&:id)) }
  scope :filter_by_original_code, -> (original_code) { where("original_code ilike ?", "%#{original_code}%") }
  # filter logic ends
  
  belongs_to :lookup_key

  def self.import(file = nil)
    file = File.new("#{Rails.root}/public/master_files/lookup_values.csv") if file.nil?
    CSV.foreach(file.path, headers: true) do |row|
      lookup_key = LookupKey.where(name: row[0].try(:strip)).first
      if lookup_key.present?
        if row["PARENT ARRAY"].present?
          row["PARENT ARRAY"].split("/").each do |ele|            
            lv_parents = self.where(original_code: ele)
            lv_code = row[2].try(:downcase).try(:strip) ? "#{lookup_key.try(:code).try(:downcase).try(:parameterize).try(:underscore)}_#{ele.try(:downcase).try(:parameterize).try(:underscore)}_#{row[2].try(:downcase).try(:parameterize).try(:underscore)}" : nil
            lookup_value = self.where(code: lv_code, original_code: row[2], lookup_key: lookup_key).first
            position = row[3].to_i rescue nil
            lv_parents.each do |lv_parent|              
              if lookup_value.nil?
                self.create(code: lv_code, original_code: row[2].try(:strip), lookup_key: lookup_key, parent: lv_parent,position:position, min_value: row['MINIMUM'], max_value: row['MAXIMUM'], is_mandatory: (row['MANDATORY'] == 'TRUE'))
              # else
              #   lookup_value.update(code: lv_code, original_code: row[2].try(:strip), lookup_key: lookup_key, parent: lv_parent,position:position, min_value: row['MINIMUM'].to_i, max_value: row['MAXIMUM'].to_i, is_mandatory: (row['MANDATORY'] == 'TRUE'))
              end
            end
          end
        elsif row[1].present?
          lv_code = row[2].try(:downcase).try(:strip) ? "#{lookup_key.try(:code).try(:downcase).try(:parameterize).try(:underscore)}_#{row[1].try(:downcase).try(:parameterize).try(:underscore)}_#{row[2].try(:downcase).try(:parameterize).try(:underscore)}" : nil
          lv_parent = self.where(original_code: row[1].strip).last
          lookup_value = self.where(code: lv_code, original_code: row[2], lookup_key: lookup_key).first
          position = row[3].to_i rescue nil
          if lookup_value.nil?
            self.create(code: lv_code, original_code: row[2].try(:strip), lookup_key: lookup_key, parent: lv_parent,position:position, min_value: row['MINIMUM'], max_value: row['MAXIMUM'], is_mandatory: (row['MANDATORY'] == 'TRUE'))
          else
            lookup_value.update(code: lv_code, original_code: row[2].try(:strip), lookup_key: lookup_key, parent: lv_parent,position:position, min_value: row['MINIMUM'].to_i, max_value: row['MAXIMUM'].to_i, is_mandatory: (row['MANDATORY'] == 'TRUE'))
          end
        else
          lv_parent = nil
          lv_code = row[2].try(:downcase).try(:strip) ? "#{lookup_key.try(:code).try(:downcase).try(:parameterize).try(:underscore)}_#{row[2].try(:downcase).try(:parameterize).try(:underscore)}" : nil
          lookup_value = self.where(code: lv_code, original_code: row[2], lookup_key: lookup_key).first
          position = row[3].to_i rescue nil
          if lookup_value.nil?
            self.create(code: lv_code, original_code: row[2].try(:strip), lookup_key: lookup_key, parent: lv_parent,position:position, min_value: row['MINIMUM'], max_value: row['MAXIMUM'], is_mandatory: (row['MANDATORY'] == 'TRUE'))
          else
            lookup_value.update(code: lv_code, original_code: row[2].try(:strip), lookup_key: lookup_key, parent: lv_parent,position:position, min_value: row['MINIMUM'].to_i, max_value: row['MAXIMUM'].to_i, is_mandatory: (row['MANDATORY'] == 'TRUE'))
          end
        end        
      end
    end
  end

  def self.rename_markdown_status
    LookupKey.where(name: 'MARKDOWN_STATUS').last.lookup_values.each do |lv|
      if lv.original_code == 'Pending Markdown Destination'
        lv.original_code = 'Pending Transfer Out Destination'
        lv.code ='markdown_status_pending_transfer_out_destination'
      elsif lv.original_code == 'Pending Markdown Dispatch'
        lv.original_code = 'Pending Transfer Out Dispatch'
        lv.code = 'markdown_status_pending_transfer_out_dispatch'
      elsif lv.original_code == 'Markdown Dispatch Complete'
        lv.original_code = 'Pending Transfer Out Dispatch Complete'
        lv.code = 'markdown_status_pending_transfer_out_dispatch_complete'
      end
      lv.save
      Markdown.where(status_id: lv.id).each do |m|
        m.status = lv.original_code
        m.save
      end
    end
  end

  def self.update_existing_inventory_statuses
    LookupKey.where(name: 'INVENTORY_STATUS_WAREHOUSE').last.lookup_values.each do |lv|
      if lv.original_code == 'Pending Markdown'
        lv.original_code = 'Pending Transfer Out'
        lv.code = 'inv_sts_warehouse_pending_transfer_out'
        lv.save
        Inventory.where(status_id: lv.id).each do |i|
          i.status = lv.original_code
          i.save
        end
      end
    end

    LookupKey.where(name: 'WAREHOUSE_DISPOSITION').last.lookup_values.each do |lv|
      if lv.original_code == 'Markdown'
        lv.original_code = 'Pending Transfer Out'
        lv.code = 'warehouse_disposition_pending_transfer_out'
        lv.save
      end
    end
  end
end
