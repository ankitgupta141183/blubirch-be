class CreateConsignmentBoxFiles < ActiveRecord::Migration[6.0]
  def change
    create_table :consignment_box_files do |t|
      t.integer :consignment_box_id
      t.integer :consignment_box_file_type_id
      t.string :consignment_box_file
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :consignment_box_files, :consignment_box_id
    add_index :consignment_box_files, :consignment_box_file_type_id
  end
end
