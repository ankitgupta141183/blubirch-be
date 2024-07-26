class CreateMasterDataInputs < ActiveRecord::Migration[6.0]
  def change
    create_table :master_data_inputs do |t|
      t.jsonb :payload
      t.string :master_data_type
      t.string :status
      t.boolean :is_error , default: false
      t.jsonb :remarks
      t.integer :success_count
      t.integer :failed_count

      t.timestamps
    end
  end
end
