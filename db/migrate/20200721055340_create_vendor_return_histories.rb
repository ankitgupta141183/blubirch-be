class CreateVendorReturnHistories < ActiveRecord::Migration[6.0]
  def change
    create_table :vendor_return_histories do |t|

      t.references :vendor_return
      t.integer :status_id
      t.jsonb :details
      t.datetime :deleted_at
      t.timestamps
    end
  end
end
