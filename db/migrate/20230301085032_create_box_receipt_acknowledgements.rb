class CreateBoxReceiptAcknowledgements < ActiveRecord::Migration[6.0]
  def change
    create_table :box_receipt_acknowledgements do |t|
      t.integer :client_id
      t.integer :user_id
      t.string :box_number
      t.integer :attachmentable_id
      t.string :attachmentable_type
      t.string :attachment_file

      t.timestamps
    end
  end
end
