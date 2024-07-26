class AddVendorNameInReplacements < ActiveRecord::Migration[6.0]
  def change
    add_column :replacements, :vendor_name, :string
  end
end
