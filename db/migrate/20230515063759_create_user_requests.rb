class CreateUserRequests < ActiveRecord::Migration[6.0]
  def change
    create_table  :user_requests do |t|
      t.integer   :user_id
      t.integer   :put_request_id

      t.timestamps
    end
  end
end
