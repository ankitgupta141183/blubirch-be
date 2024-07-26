class ClientCategoryMapping < ApplicationRecord
	belongs_to :category
	belongs_to :client_category
	acts_as_paranoid

	def self.import(file)

		error_flag = 0
		error_log = []
		error_row = 0
		CSV.foreach(file.path, headers: true) do |row|
			errors = []
			client_child = nil
			child = nil
			(1..6).to_a.each do |i|
				if i==1
					client_parent = ClientCategory.find_by(code:row["client_cat_l#{i}"])
				else
					client_child = ClientCategory.find_by(code:row["client_cat_l#{i}"])
					prev_client_child = ClientCategory.find_by(code:row["client_cat_l#{i-1}"])

					if client_child.present? && !client_child.child_of?(prev_client_child)
						errors << "client_cat_l#{i} is not child of client_cat_l#{i-1}"
						error_flag = 1
						
					end

					if !client_child.present?
						# next_client_child = ClientCategory.find_by(code:row["client_cat_l#{i+1}"])
						if i<6 && row["client_cat_l#{i+1}"].present?
						    error_flag =1
							errors << "client_cat_l#{i} is blank "
							break
						else
							client_child = ClientCategory.find_by(code:row["client_cat_l#{i-1}"])
							break
						end	
					end
					
				end

			end
			(1..6).to_a.each do |i|
				if i==1
					parent = Category.find_by(code:row["cat_l#{i}"])
				else
					child = Category.find_by(code:row["cat_l#{i}"])
					prev_child = Category.find_by(code:row["cat_l#{i-1}"])

					if child.present? && !child.child_of?(prev_child)
						errors << "cat_l#{i} is not child of cat_l#{i-1}"
						error_flag = 1
						
					end

					if !child.present?

						if i<6 && row["cat_l#{i+1}"].present?
						    error_flag =1
							errors << "cat_l#{i} is blank "
							break
						else
							child = Category.find_by(code:row["cat_l#{i-1}"])
							break
						end	

					end
					
				end

			end

			if error_flag == 0
				puts "===============#{client_child}========hello=========#{child}========================"
				c=ClientCategoryMapping.new(client_category_id: client_child.id , category_id: child.id)
				c.save
			end

			error_log << errors
			error_row = error_row + 1


		end

		return error_log

	end


end
