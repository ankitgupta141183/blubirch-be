class CreateClientAttributeMasters < ActiveRecord::Migration[6.0]
  def change
    create_table :client_attribute_masters do |t|
    	t.string :attr_type
    	t.string :reason
    	t.string :attr_label
    	t.string :field_type
    	t.text :options
    	t.datetime :deleted_at
    	t.integer :client_id

    	t.timestamps
    end
    add_index :client_attribute_masters, :client_id
  end
end
