class CreateReturnItems < ActiveRecord::Migration[6.0]
  def change
    create_table :return_items do |t|
      t.string :return_request_id
      t.string :return_sub_request_id
      t.string :return_type
      t.string :channel
      t.integer :status_id
      t.string :status
      t.string :return_reason
      t.string :return_sub_reason
      t.string :return_request_sub_type
      t.string :item_location
      t.string :sku_code
      t.string :invoice_number
      t.string :quantity

      t.timestamps
    end

    add_index :return_items, :return_request_id
    add_index :return_items, :return_sub_request_id
    add_index :return_items, :status_id
    add_index :return_items, :sku_code
    add_index :return_items, :invoice_number

  end
end
