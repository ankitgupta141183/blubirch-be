class CreateOndcOrderHistories < ActiveRecord::Migration[6.0]
  def change
    create_table :ondc_order_histories do |t|
      t.references :ondc_order
      t.string :order_state
      t.date :history_date
      t.timestamps
    end
  end
end
