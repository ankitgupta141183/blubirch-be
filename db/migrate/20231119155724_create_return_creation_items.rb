class CreateReturnCreationItems < ActiveRecord::Migration[6.0]
  def change
    create_table :return_creation_items do |t|
      t.string :batch_number
      t.jsonb :payload
      t.jsonb :remarks
      t.integer :total_items
      t.integer :success_item_count
      t.integer :failure_item_count
      t.boolean :is_error , default: true
      t.string :status
      t.timestamps
    end
  end
end
