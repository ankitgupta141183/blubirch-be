class CreateConsignmentAttachments < ActiveRecord::Migration[6.0]
  def change
    create_table :consignment_attachments do |t|
      t.references :consignment_information
      t.string :attachment_file
      t.string :attachment_type
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
