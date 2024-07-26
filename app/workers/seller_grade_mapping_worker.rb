class SellerGradeMappingWorker
  include Sidekiq::Worker

  def perform
    grades_csv = CSV.read("#{Rails.root}/public/master_files/grade_mapping.csv", :headers=>true)
    grades_csv.each do |grade|
      GradeMapping.find_or_create_by( client_item_name: grade["Client Grade"], seller_item_name: grade["Seller Grade"])
    end
  end
end
