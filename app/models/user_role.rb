class UserRole < ApplicationRecord
	acts_as_paranoid
	belongs_to :user
  belongs_to :role
  validates :user_type, inclusion: { in: ['forward', 'reverse'],
                                 allow_blank: true,
                                 message:     "Please provide valid user type" }

end
