# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

user = User.find_or_create_by!(username: "superadmin") do |user|
  user.first_name = "Super"
  user.last_name = "Admin"
  user.email = "it@blubirch.com"
  user.password = "blubirch123"
  user.password_confirmation = "blubirch123"
  role = Role.find_or_create_by(name: "Superadmin", code: "superadmin")
  user.roles = [role]
end

roles = [{name: "Store Owner", code: "store_owner"}, {name: "Store User", code: "store_user"}, {name: "Pickup Executive", code: "pickup_executive"},{name: "Store Head", code: "store_head"}, {name: "DC Owner", code: "dc_owner"}, {name: "DC User", code: "dc_user"},{name: "Service Executive", code: "service_executive"},{name: "Warehouse User", code:"warehouse"},{name: "Dashboard Admin", code: "dashboard_admin"},{name: "Dealer User", code: "dealer_user"},{name: "Forward", code: "forward"},{name: "Reverse", code: "reverse"}]

roles.each do |role|
	Role.find_or_create_by(code: role[:code], name: role[:name])
end

Client.bootstrap_data