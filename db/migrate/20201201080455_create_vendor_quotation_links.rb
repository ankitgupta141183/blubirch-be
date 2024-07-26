class CreateVendorQuotationLinks < ActiveRecord::Migration[6.0]
  def change
    create_table :vendor_quotation_links do |t|
      t.references  :vendor_master
      t.references  :liquidation_order
      t.string :token
      t.datetime :expiry_date

      t.timestamps
    end
  end
end