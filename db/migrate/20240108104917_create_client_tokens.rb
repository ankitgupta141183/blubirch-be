class CreateClientTokens < ActiveRecord::Migration[6.0]
  def change
    create_table :client_tokens do |t|
      t.string :integration_name, null: false
      t.string :api_token, null: false
      t.datetime :last_used_at

      t.timestamps
    end
    add_index :client_tokens, :integration_name, unique: true
  end
end