class DealerUser < ApplicationRecord
	acts_as_paranoid
	belongs_to :user
	belongs_to :dealer

	def self.create_dealer_user(dealer_id)
		dealer = Dealer.find(dealer_id)
	  role = Role.find_by(name: "Dealer User", code: "dealer_user")
		user = User.find_or_create_by!(username: dealer.first_name) do |user|
		  user.first_name = dealer.first_name
		  user.last_name = dealer.last_name
		  user.email = dealer.email
		  user.contact_no = dealer.phone_number
		  user.password = dealer.first_name.chars.first(4).join + dealer.gst_number.chars.first(4).join
		  user.password_confirmation = dealer.first_name.chars.first(4).join + dealer.gst_number.chars.first(4).join
		  user.roles = [role]
		end
		DealerUser.create(user_id: user.id, dealer_id: dealer.id)
	end

end
