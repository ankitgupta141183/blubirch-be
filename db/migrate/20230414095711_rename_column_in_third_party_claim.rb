class RenameColumnInThirdPartyClaim < ActiveRecord::Migration[6.0]
  def change
    rename_column :third_party_claims, :vendor, :vendor_code
  end
end