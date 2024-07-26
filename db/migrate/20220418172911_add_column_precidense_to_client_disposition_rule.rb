class AddColumnPrecidenseToClientDispositionRule < ActiveRecord::Migration[6.0]
  def change
    add_column :client_disposition_rules, :grade_precedence, :integer
    add_column :client_disposition_rules, :grade, :string
  end
end
