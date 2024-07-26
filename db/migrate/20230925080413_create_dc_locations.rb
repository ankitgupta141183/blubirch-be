class CreateDcLocations < ActiveRecord::Migration[6.0]
  def change
    create_table :dc_locations do |t|
      t.string :pincode
      t.string :dc_code
      t.string :destination_code
      t.integer :distribution_center_id
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
