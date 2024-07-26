class CreateErrors < ActiveRecord::Migration[6.0]
  def change
    create_table :errors do |t|
      t.datetime :timestamp
      t.string :error_type
      t.text :error_message
      t.string :error_code
      t.string :user
      t.text :request
      t.text :stack_trace
      t.text :additional_metadata
      t.string :resource_id

      t.timestamps
    end
  end
end
