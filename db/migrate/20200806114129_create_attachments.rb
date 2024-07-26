class CreateAttachments < ActiveRecord::Migration[6.0]
  def change
    create_table :attachments do |t|

      t.string :attachable_type
      t.integer :attachable_id
      t.string :file
      t.string :document_type
      t.string :reference_number
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
