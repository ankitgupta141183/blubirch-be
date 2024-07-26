class CreateCustomerReturnReasons < ActiveRecord::Migration[6.0]
	def change
		create_table :customer_return_reasons do |t|
			t.string :name
			t.boolean :grading_required, default: false
			t.datetime :deleted_at

			t.timestamps
		end
	end
end
