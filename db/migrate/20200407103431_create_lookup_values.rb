class CreateLookupValues < ActiveRecord::Migration[6.0]
  def change
    create_table :lookup_values do |t|
      t.integer :lookup_key_id
      t.string :code
      t.float :position
      t.string :ancestry
      t.string :original_code
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :lookup_values, :lookup_key_id
    add_index :lookup_values, :ancestry
  end
end
