class CreateGradingRules < ActiveRecord::Migration[6.0]
  def change
    create_table :grading_rules do |t|
      t.jsonb :rules
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
