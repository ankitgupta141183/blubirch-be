class CreateBucketInformations < ActiveRecord::Migration[6.0]
  def change
    create_table :bucket_informations do |t|
      t.string :distribution_center_code
      t.integer :distribution_center_id
      t.string :info_type
      t.jsonb :bucket_status
      t.timestamps
    end
    add_index :bucket_informations, :distribution_center_id
  end
end
