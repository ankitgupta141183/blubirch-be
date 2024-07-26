class Order < ApplicationRecord
	acts_as_paranoid
	belongs_to :user
	belongs_to :client
	belongs_to :order_type , class_name: "LookupValue", foreign_key: "order_type_id"

	validates :order_number, presence: true, uniqueness: true

	include Filterable
  scope :filter_by_client_id, -> (client_id) { where("client_id in (?)", client_id)}
  scope :filter_by_user_id, -> (user_id) { where("user_id in (?)", user_id)}
  scope :filter_by_order_number, -> (order_number) { where("order_number ilike ?", "%#{order_number}%")}
  scope :filter_by_order_type_id, -> (order_type_id) { where("order_type_id in (?)", order_type_id)}  


  def self.import(file)
		CSV.foreach(file.path, headers: true) do |row|
			client = Client.where(name: row["Client"]).first
			user = User.where(username: row["Username"]).first
			order_type = LookupValue.where(original_code: row["Order Type"]).first
			if client.present? && user.present? && order_type.present?
				self.create(client_id: client.try(:id) , user_id: user.try(:id), order_type_id: order_type.try(:id), order_number: row["Order Number"].try(:strip) , from_address: row["From Address"].try(:strip), to_address: row["To Address"].try(:strip))
			end
		end
	end

end
