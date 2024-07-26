class CreateRentalEmis < ActiveRecord::Migration[6.0]
  def change
    create_table :rental_emis do |t|
      t.references :rental
      t.date :start_date
      t.date :end_date
      t.decimal :received_rental
      t.date :received_date

      t.timestamps
    end
  end
end
