class CreateMasterFileUploads < ActiveRecord::Migration[6.0]
  def change
    create_table :master_file_uploads do |t|
      t.string :master_file_type
      t.string :master_file
      t.string :status
      t.text :remarks
      t.integer :user_id
      t.integer :client_id

      t.timestamps
    end
    add_index :master_file_uploads, :user_id
    add_index :master_file_uploads, :client_id
  end
end
