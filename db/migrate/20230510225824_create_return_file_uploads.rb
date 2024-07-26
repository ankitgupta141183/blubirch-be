class CreateReturnFileUploads < ActiveRecord::Migration[6.0]
  def change
    create_table :return_file_uploads do |t|
      t.string :return_file
      t.string :return_type
      t.string :status
      t.integer :user_id
      t.integer :client_id
      t.text :remarks
      t.datetime :deleted_at
      t.timestamps
    end
  end
end
