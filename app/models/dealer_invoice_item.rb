class DealerInvoiceItem < ApplicationRecord
	acts_as_paranoid
  belongs_to :dealer_invoice
end
