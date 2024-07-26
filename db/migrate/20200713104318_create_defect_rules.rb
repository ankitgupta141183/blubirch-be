class CreateDefectRules < ActiveRecord::Migration[6.0]
  def change
    create_table :defect_rules do |t|
      t.json :rules
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
