class CreateRtvSettlements < ActiveRecord::Migration[6.0]
  def change
    create_table :rtv_settlements do |t|

      t.integer :claim_id
      t.float :saved_amount
      t.float :approved_amount
      t.string :attachment_file
      t.integer :status_id
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :rtv_settlements, :claim_id
    add_index :rtv_settlements, :status_id
  end
end
