class CreateEcomRequestHistories < ActiveRecord::Migration[6.0]
  def change
    create_table :ecom_request_histories do |t|
      t.references :liquidation
      t.text :response_body
      t.integer :status
      t.text :response_data
      t.timestamps
    end
  end
end
