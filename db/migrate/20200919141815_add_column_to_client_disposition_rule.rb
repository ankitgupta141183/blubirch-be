class AddColumnToClientDispositionRule < ActiveRecord::Migration[6.0]
  def change
    add_column :client_disposition_rules, :return_reason, :string
    add_column :client_disposition_rules, :label, :string
    add_column :client_disposition_rules, :flow_name, :string
  end
end
