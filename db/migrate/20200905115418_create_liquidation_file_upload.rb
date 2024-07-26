class CreateLiquidationFileUpload < ActiveRecord::Migration[6.0]
  def change
    create_table :liquidation_file_uploads do |t|
      t.string :liquidation_file
      t.string :status
      t.integer :user_id
      t.integer :client_id
      t.text :remarks
      t.timestamps
    end
  end
end
