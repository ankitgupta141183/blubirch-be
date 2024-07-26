class CreateDistributionCenters < ActiveRecord::Migration[6.0]
  def change
    create_table :distribution_centers do |t|
      t.string :name
      t.string :address_line1
      t.string :address_line2
      t.string :address_line3
      t.string :address_line4
      t.integer :city_id
      t.integer :state_id
      t.integer :country_id
      t.string :ancestry
      t.jsonb :details
      t.integer :distribution_center_type_id
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :distribution_centers, :city_id
    add_index :distribution_centers, :state_id
    add_index :distribution_centers, :country_id
    add_index :distribution_centers, :ancestry
    add_index :distribution_centers, :distribution_center_type_id
  end
end
