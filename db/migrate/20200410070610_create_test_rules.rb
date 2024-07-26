class CreateTestRules < ActiveRecord::Migration[6.0]
  def change
    create_table :test_rules do |t|
      t.jsonb :rules
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
