class CreateConsignmentFiles < ActiveRecord::Migration[6.0]
  def change
    create_table :consignment_files do |t|

      t.integer :consignment_id
      t.integer :consignment_file_type_id
      t.string :consignment_file
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :consignment_files, :consignment_id
    add_index :consignment_files, :consignment_file_type_id
  end
end