class EmailTemplate < ApplicationRecord

  acts_as_paranoid

    validates :name, :template, presence: true


  # filter logic starts
  include Filterable
  scope :filter_by_name, -> (name) { where("name ilike ?", "%#{name}%")}
  scope :filter_by_template, -> (template) { where("template ilike ?", "%#{template}%")}
  scope :filter_by_template_type_id, -> (template_type_id) { where template_type_id: template_type_id }
  # filter logic ends

  def self.import(file)
    begin
      i = 1
      ActiveRecord::Base.transaction do
        email_templates = CSV.read(file.path, headers: true)
        email_templates.each do |row|
          i = i+1
          template_type = LookupValue.where(original_code: row[1].try(:strip)).last.id
          email_template = EmailTemplate.where(name: row[0].try(:strip)).last
          if email_template.present?
            email_template.update_attributes(template_type_id: template_type, template: row[2].try(:strip))
          else
            email_template = EmailTemplate.new(name: row[0].try(:strip), template_type_id: template_type, template: row[2].try(:strip))
            email_template.save
          end
        end
      end
    rescue Exception => message
      return "Line Number #{i}:"+message.to_s
    end
  end

end
