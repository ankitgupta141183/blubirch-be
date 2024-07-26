class CreateTaskManagers < ActiveRecord::Migration[6.0]
  def change
    create_table :task_managers do |t|
      t.string   :task_name
      t.datetime :run_at
      t.integer  :time_taken
      t.integer  :status, limit: 1
      t.string   :result

      t.timestamps
    end

    add_index :task_managers, :created_at
  end
end
