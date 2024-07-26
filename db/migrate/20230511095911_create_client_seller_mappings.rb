class CreateClientSellerMappings < ActiveRecord::Migration[6.0]
  def change
    create_table :client_seller_mappings do |t|
      t.string :client_item_name
      t.string :seller_item_name
      t.string :type

      t.timestamps
    end
  end
end
