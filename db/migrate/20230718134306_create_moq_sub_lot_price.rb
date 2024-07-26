class CreateMoqSubLotPrice < ActiveRecord::Migration[6.0]
  def change
    create_table :moq_sub_lot_prices do |t|
      t.references :liquidation_order
      t.integer    :from_lot
      t.integer    :to_lot
      t.integer    :price_per_lot

      t.timestamps
    end
  end
end
