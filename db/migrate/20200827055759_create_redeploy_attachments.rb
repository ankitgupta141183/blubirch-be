class CreateRedeployAttachments < ActiveRecord::Migration[6.0]
  def change
    create_table :redeploy_attachments do |t|
    	t.integer :attachable_id
    	t.string :attachable_type
    	t.string :attachment_file
    	t.string :attachment_file_type
    	t.integer :attachment_file_type_id
    	t.datetime :deleted_at
      t.timestamps
    end
  end
end