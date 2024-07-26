class UserSerializer < ActiveModel::Serializer
  
  attributes :id, :email, :first_name, :last_name, :username, :contact_no

  has_many :roles
  has_many :distribution_centers

  
end
