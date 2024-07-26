class CreateEWasteOrderVendors < ActiveRecord::Migration[6.0]
  def change
    create_table :e_waste_order_vendors do |t|
      t.references  :e_waste_order
      t.references  :vendor_master

      t.timestamps
    end
  end
end
