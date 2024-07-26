class CreateRepairAttachments < ActiveRecord::Migration[6.0]
  def change
    create_table :repair_attachments do |t|
      t.integer :attachment_type_id
      t.string :attachment_type
      t.string :attachable_type
      t.integer :attachable_id
      t.string :attachment_file
      t.timestamps
    end
  end
end