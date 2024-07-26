class CreateVendorRateCard < ActiveRecord::Migration[6.0]
  def change
    create_table :vendor_rate_cards do |t|
      t.references :vendor_master
      t.string     :sku_master_code
      t.text       :sku_description
      t.float      :mrp
      t.string     :item_condition
      t.float      :contracted_rate
      t.float      :contracted_rate_percentage

      t.timestamps
    end
  end
end
