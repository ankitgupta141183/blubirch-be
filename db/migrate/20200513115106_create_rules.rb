class CreateRules < ActiveRecord::Migration[6.0]
  def change
    create_table :rules do |t|
      t.jsonb :precedence
      t.jsonb :rule_definition
      t.jsonb :condition
      t.timestamps
    end
  end
end
