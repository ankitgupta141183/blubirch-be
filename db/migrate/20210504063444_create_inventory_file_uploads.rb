class CreateInventoryFileUploads < ActiveRecord::Migration[6.0]
  def change
    create_table :inventory_file_uploads do |t|
      t.string :inventory_file
      t.string :status
      t.text :remarks
      t.integer :user_id
      t.integer :client_id
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :inventory_file_uploads, :user_id
    add_index :inventory_file_uploads, :client_id
  end
end
