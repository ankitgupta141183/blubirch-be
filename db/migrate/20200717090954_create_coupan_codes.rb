class CreateCoupanCodes < ActiveRecord::Migration[6.0]
  def change
    create_table :coupan_codes do |t|
      t.string :coupan_code
      t.integer :discount

      t.timestamps
    end
  end
end
