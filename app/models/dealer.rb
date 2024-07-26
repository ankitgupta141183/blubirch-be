class Dealer < ApplicationRecord
	acts_as_paranoid
	has_ancestry
	has_many :dealer_users
  has_many :users, through: :dealer_users

end
