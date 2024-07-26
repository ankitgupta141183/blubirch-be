class AddNewColumnsToVendoReturnsTable < ActiveRecord::Migration[6.0]
  def change
    add_column :vendor_returns, :claim_rgp_number, :string
    add_column :vendor_returns, :claim_replacement_location, :string
    add_column :vendor_returns, :inspection_rgp_number, :string
    add_column :vendor_returns, :inspection_replacement_location, :string
    add_column :vendor_returns, :sr_number, :string
    add_column :vendor_returns, :serial_number, :string
    add_column :vendor_returns, :serial_number2, :string
    add_column :vendor_returns, :toat_number, :string
    add_column :vendor_returns, :aisle_location, :string
    add_column :vendor_returns, :client_tag_number, :string
  end
end
