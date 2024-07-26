class CreatePushInbounds < ActiveRecord::Migration[6.0]
  def change
    create_table :push_inbounds do |t|
      t.jsonb :payload
      t.string :master_data_type
      t.string :reference_number
      t.string :status
      t.boolean :is_error , default: false
      t.jsonb :response

      t.datetime :deleted_at
      t.timestamps
    end
  end
end
