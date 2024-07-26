class AddClaimEmailDateColumnToVendorReturns < ActiveRecord::Migration[6.0]
  def change
    add_column :vendor_returns, :claim_email_date, :datetime
  end
end
