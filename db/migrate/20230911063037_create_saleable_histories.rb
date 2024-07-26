class CreateSaleableHistories < ActiveRecord::Migration[6.0]
  #saleable_id
  #status_id
  #details
  #status 
  def change
    create_table :saleable_histories do |t|
      t.references :saleable
      t.integer :status_id
      t.jsonb :details
      t.string :status
      t.timestamps
    end
  end
end
