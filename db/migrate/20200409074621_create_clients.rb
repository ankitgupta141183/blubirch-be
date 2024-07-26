class CreateClients < ActiveRecord::Migration[6.0]
  def change
    create_table :clients do |t|
      t.string :name
      t.string :domain_name
      t.string :address_line1
      t.string :address_line2
      t.string :address_line3
      t.string :address_line4
      t.jsonb :details
      t.integer :city_id
      t.integer :state_id
      t.integer :country_id
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
