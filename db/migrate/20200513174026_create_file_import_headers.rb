class CreateFileImportHeaders < ActiveRecord::Migration[6.0]
  def change
    create_table :file_import_headers do |t|
    	t.string :name
    	t.string :headers
    	t.boolean :is_hash, default: true
    	t.datetime :deleted_at
      t.timestamps
    end
  end
end
