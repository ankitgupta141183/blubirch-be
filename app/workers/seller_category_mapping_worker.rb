class SellerCategoryMappingWorker
  include Sidekiq::Worker

  def perform
    categories_csv = CSV.read("#{Rails.root}/public/master_files/category_mapping.csv", :headers=>true)
    seller_categories = []
    SellerCategory.delete_all
    categories_csv.each do |category|
      client_category = ClientCategory.find_by(name: category["Client Category L3"])
      if client_category.present?
        details = category.to_hash.slice(*["Category L1", "Category L2", "Category L3", "Category L4", "Category L5", "Category L6", "Bmaxx Parent", "Bmaxx Child"]).compact.transform_keys!{ |key| key.to_s.parameterize.underscore }
        seller_categories << { details: details, client_category_id: client_category.id }
      end
    end
    SellerCategory.create(seller_categories)
  end
end
