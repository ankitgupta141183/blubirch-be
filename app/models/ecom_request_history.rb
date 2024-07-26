class EcomRequestHistory < ApplicationRecord

  belongs_to :liquidation
  enum status: { sent: 1, success: 2, failed: 3 }, _prefix: true 

end
