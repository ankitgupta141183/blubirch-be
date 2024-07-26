class CreateInsuranceHistories < ActiveRecord::Migration[6.0]
  def change
    create_table :insurance_histories do |t|

      t.integer :insurance_id
      t.integer :status_id
      t.jsonb :details
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :insurance_histories, :insurance_id
    add_index :insurance_histories, :status_id
  end
end
