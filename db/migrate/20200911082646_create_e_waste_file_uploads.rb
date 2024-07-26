class CreateEWasteFileUploads < ActiveRecord::Migration[6.0]
  def change
    create_table :e_waste_file_uploads do |t|
      t.string :e_waste_file
      t.string :status
      t.string :user_id
      t.string :client_id
      t.text :remarks
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
