class AddTabStatusInThirdPartyClaims < ActiveRecord::Migration[6.0]
  def change
    add_column :third_party_claims, :tab_status, :integer
  end
end
