class UserRequest < ApplicationRecord
  belongs_to :user
  belongs_to :put_request
end
