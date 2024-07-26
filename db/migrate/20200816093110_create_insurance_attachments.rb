class CreateInsuranceAttachments < ActiveRecord::Migration[6.0]
  def change
    create_table :insurance_attachments do |t|

      t.string :attachable_type
      t.integer :attachable_id
      t.string :attachment_file
      t.string :attachment_file_type
      t.timestamps
    end
  end
end
