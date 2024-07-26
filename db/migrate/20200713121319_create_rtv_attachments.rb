class CreateRtvAttachments < ActiveRecord::Migration[6.0]
  def change
    create_table :rtv_attachments do |t|

      t.string :attachable_type
      t.string :attachable_id
      t.string :attachment_file
      t.timestamps
    end
  end
end
