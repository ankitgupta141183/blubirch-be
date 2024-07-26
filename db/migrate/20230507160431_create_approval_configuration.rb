class CreateApprovalConfiguration < ActiveRecord::Migration[6.0]
  def change
    create_table :approval_configurations do |t|
      t.string :approval_name
      t.string :approval_config_type
      t.string :approval_flow
      t.integer :approval_count

      t.timestamps
    end

    create_table :approval_users do |t|
      t.integer :approval_configuration_id
      t.integer :user_id
      t.integer :heirarchy_level

      t.timestamps
    end

    create_table :approval_requests do |t|
      t.references :approvable, polymorphic: true
      t.integer :approval_configuration_id
      t.datetime :approved_on
      t.jsonb :approval_hash

      t.timestamps
    end
  end
end
