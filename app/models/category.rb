class Category < ApplicationRecord

  has_logidze
	has_ancestry
  acts_as_paranoid

  validates :name, :code, presence: true

  # filter logic starts
  include Filterable
  scope :filter_by_name, -> (name) { where("name ilike ?", "%#{name}%")}
  scope :filter_by_code, -> (code) { where("code ilike ?", "%#{code}%")}
  scope :filter_by_ancestry, -> (ancestry) { where("id in (?)", where("id in (?)", ancestry).collect(&:children).flatten.collect(&:id)) }
  # filter logic ends
  
  has_many :client_category_mappings
  has_many :client_categories, through: :client_category_mappings
  has_many :disposition_rules

  has_one :category_grading_rule

	serialize :attrs, Array


	def self.import_categories(file = nil)
    file = File.new("#{Rails.root}/public/master_files/category_attributes.csv") if file.nil?
    categories = CSV.read(file.path ,headers:true)
	  categories.each do |category|
	  	category_array = [category[0].try(:strip), category[1].try(:strip), category[2].try(:strip), category[3].try(:strip), category[4].try(:strip), category[5].try(:strip)]
      new_category = category_array.compact

      new_category.each_with_index do |individual_category, index|
      	if index == 0
      		code_name = "l#{index+1}_#{individual_category.parameterize.underscore}"
      	else
      		parent_name = new_category[index-1]
      		if index == 1
      			parent_category = Category.where("code = ?", "l#{index}_#{parent_name.parameterize.underscore}").first
	      	else
	      		pre_parent_name = new_category[index-2]
	      		parent_category = Category.where("code = ?", "#{pre_parent_name.parameterize.underscore}_l#{index}_#{parent_name.parameterize.underscore}").first
	      	end
      		code_name = "#{parent_name.parameterize.underscore}_l#{index+1}_#{individual_category.parameterize.underscore}"
      	end
      	cat_code = Category.where("code = ?", code_name).first
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
      			Category.create(name: individual_category, parent: parent_category, attrs: val, code: "l#{index+1}_#{individual_category.parameterize.underscore}")
      		else
      			Category.create(name: individual_category, parent: parent_category, attrs: val, code: "#{parent_name.parameterize.underscore}_l#{index+1}_#{individual_category.parameterize.underscore}")
      		end
      	end
      end

	  end
  end

end
