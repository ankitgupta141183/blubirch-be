class DealerCustomer < ApplicationRecord
	acts_as_paranoid
  # filter logic starts
  include Filterable
  scope :filter_by_name, -> (name) { where("name ilike ?", "%#{name}%")}
  scope :filter_by_phone_number, -> (phone_number) { where("phone_number = ?", "#{phone_number}")}
  scope :filter_by_email, -> (email) { where("email ilike ?", "%#{email}%")}
  scope :filter_by_gst_number, -> (gst_number) { where("gst_number ilike ?", "%#{gst_number}%")}
  # filter logic ends

end
