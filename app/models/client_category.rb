class ClientCategory < ApplicationRecord
  
  has_ancestry
  acts_as_paranoid
  validates :name, :code, presence: true

  # filter logic starts
  include Filterable
  scope :filter_by_client_id, -> (client_id) { where client_id: client_id }
  scope :filter_by_name, -> (name) { where("name ilike ?", "%#{name}%")}
  scope :filter_by_code, -> (code) { where("code ilike ?", "%#{code}%")}
  scope :filter_by_ancestry, -> (ancestry) { where ancestry: ancestry }
  scope :active, -> { where(deleted_at: nil ) }
  # filter logic ends

  has_many  :client_sku_masters
  has_many :client_category_mappings
  has_many :liquidations
  has_many :categories, through: :client_category_mappings
  has_many :inventories
  belongs_to :client
  has_one :seller_category

  has_many :client_category_grading_rules

  serialize :attrs, Array

  def self.json_tree(client_categories:)
    client_categories.map do |category|
      {:name => category.name, :id => category.id, :children => ClientCategory.json_tree(client_categories: category.children).compact}
    end
  end

  #ClientCategory.cache_json_tree_into_redis
  def self.cache_json_tree_into_redis
    Rails.cache.fetch("cache_json_tree_into_redis", expires_in: 1.hour) do
      ClientCategory.active.json_tree(client_categories: ClientCategory.active.roots)
    end
  end
  
  def self.import_client_categories(file = nil,client_id = nil)
    if file.present? && client_id.present?
      categories = CSV.read(file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
    else
      if file.nil?
        account_setting = AccountSetting.first
        file_name = account_setting&.liquidation_client_category_file_path || 'public/master_files/client_category_attributes.csv'
        file = File.new("#{Rails.root}/#{file_name}")
      end
      if (Client.all.size == 1)
        client_id = Client.first.id
      else
        raise "Client Information not present"
      end
      categories = CSV.read(file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
    end
    categories.each do |category|
      category_array = [category[0].try(:strip), category[1].try(:strip), category[2].try(:strip), category[3].try(:strip), category[4].try(:strip), category[5].try(:strip)]
      new_category = category_array.compact

      new_category.each_with_index do |individual_category, index|
        if index == 0
          code_name = "l#{index+1}_#{individual_category.parameterize.underscore}"
        else
          parent_name = new_category[index-1]
          if index == 1
            parent_category = ClientCategory.where("code = ?", "l#{index}_#{parent_name.parameterize.underscore}").first
          else
            pre_parent_name = new_category[index-2]
            parent_category = ClientCategory.where("code = ?", "#{pre_parent_name.parameterize.underscore}_l#{index}_#{parent_name.parameterize.underscore}").first
          end
          code_name = "#{parent_name.parameterize.underscore}_l#{index+1}_#{individual_category.parameterize.underscore}"
        end
        cat_code = ClientCategory.where("code = ? and client_id = ? ", code_name, client_id).first
        if cat_code.nil?
          if new_category.size == (index+1)
            val = []
            categories.headers.each do |header|
              attr = AttributeMaster.where("attr_label = ?", header).first
              if attr.present? && category[header] == "1"
                val << {name: header, type: attr.field_type, values: attr.options, is_sku_attr: false, param_name: header.parameterize.underscore}
              elsif attr.present? && category[header] == "11"
                val << {name: header, type: attr.field_type, values: attr.options, is_sku_attr: true, param_name: header.parameterize.underscore}
              end
            end
          else
            val = []
          end
          if index == 0
            ClientCategory.create(name: individual_category, client_id: client_id, parent: parent_category, attrs: val, code: "l#{index+1}_#{individual_category.parameterize.underscore}")
          else
            ClientCategory.create(name: individual_category, client_id: client_id, parent: parent_category, attrs: val, code: "#{parent_name.parameterize.underscore}_l#{index+1}_#{individual_category.parameterize.underscore}")
          end
        end
      end

    end
  end

  def self.import_categories(file = nil,client_id = nil)
    if file.present? && client_id.present?
      categories = CSV.read(file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
    else
      if file.nil?
        account_setting = AccountSetting.first
        file_name = account_setting&.liquidation_client_category_file_path || 'public/internal_wms/category_master.csv'
        file = File.new("#{Rails.root}/#{file_name}")
      end
      if (Client.all.size == 1)
        client_id = Client.first.id
      else
        raise "Client Information not present"
      end
      categories = CSV.read(file.path, {headers: true, encoding: "iso-8859-1:utf-8"})
    end
    categories.each do |category|
      category_array = [category[0].try(:strip), category[1].try(:strip), category[2].try(:strip), category[3].try(:strip), category[4].try(:strip), category[5].try(:strip)]
      new_category = category_array.compact

      new_category.each_with_index do |individual_category, index|
        if index == 0
          code_name = "l#{index+1}_#{individual_category.parameterize.underscore}"
        else
          parent_name = new_category[index-1]
          if index == 1
            parent_category = ClientCategory.where("code = ?", "l#{index}_#{parent_name.parameterize.underscore}").first
          else
            pre_parent_name = new_category[index-2]
            parent_category = ClientCategory.where("code = ?", "#{pre_parent_name.parameterize.underscore}_l#{index}_#{parent_name.parameterize.underscore}").first
          end
          code_name = "#{parent_name.parameterize.underscore}_l#{index+1}_#{individual_category.parameterize.underscore}"
        end
        cat_code = ClientCategory.where("code = ? and client_id = ? ", code_name, client_id).first
        if cat_code.nil?
          if new_category.size == (index+1)
            category_code = category["Category Code"].present? ? category["Category Code"] : nil
            val = []
            categories.headers.each do |header|
              attr = AttributeMaster.where("attr_label = ?", header).first
              if attr.present? && category[header] == "1"
                val << {name: header, type: attr.field_type, values: attr.options, is_sku_attr: false, param_name: header.parameterize.underscore}
              elsif attr.present? && category[header] == "11"
                val << {name: header, type: attr.field_type, values: attr.options, is_sku_attr: true, param_name: header.parameterize.underscore}
              end
            end
          else
            val = []
          end
          if index == 0
            ClientCategory.create(name: individual_category, client_id: client_id, parent: parent_category, attrs: val, code: "l#{index+1}_#{individual_category.parameterize.underscore}", cat_code: category_code)
          else
            ClientCategory.create(name: individual_category, client_id: client_id, parent: parent_category, attrs: val, code: "#{parent_name.parameterize.underscore}_l#{index+1}_#{individual_category.parameterize.underscore}", cat_code: category_code)
          end
        end
      end

    end
  end


end