class CreateVendorDistributions < ActiveRecord::Migration[6.0]
  def change
    create_table :vendor_distributions do |t|

      t.references :distribution_center
      t.references :vendor_master
      t.timestamps
    end
  end
end