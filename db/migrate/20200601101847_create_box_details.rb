class CreateBoxDetails < ActiveRecord::Migration[6.0]
  def change
    create_table :box_details do |t|
      t.integer :consignment_box_id
      t.jsonb :details
      t.integer :box_condition_id
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :box_details, :consignment_box_id
    add_index :box_details, :box_condition_id

  end
end
