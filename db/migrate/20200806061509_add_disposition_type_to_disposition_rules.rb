class AddDispositionTypeToDispositionRules < ActiveRecord::Migration[6.0]
  def change
    add_column :disposition_rules, :disposition_type, :string
  end
end
