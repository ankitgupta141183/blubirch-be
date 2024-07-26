class AddJsonColumnInGatePasses < ActiveRecord::Migration[6.0]
  def change
    add_column :gate_passes, :details, :jsonb
  end
end
