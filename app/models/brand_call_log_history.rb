class BrandCallLogHistory < ApplicationRecord
  belongs_to :brand_call_log
  belongs_to :status, class_name: 'LookupValue', foreign_key: "status_id"
  
end
