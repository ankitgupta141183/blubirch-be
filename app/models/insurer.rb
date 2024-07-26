class Insurer < ApplicationRecord
  has_many :insurances
  
  enum insurance_value_parameter: { purchase_price: 1, map: 2, asp: 3, mrp: 4 }, _prefix: true                   # map - moving avg price, asp - avg selling price, mrp - maximum retail price
  enum claim_raising_method: { api: 1, email: 2, offline: 3}, _prefix: true
  
  validates_presence_of :name, :insurance_claim_type, :required_documents
  
  DATA_TYPES = %w[info doc image video]
  
  def added_on
    format_ist_time(created_at)
  end
end
