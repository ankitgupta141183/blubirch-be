class Api::V2::InventorySerializer < ActiveModel::Serializer
  attributes :tag_number, :name, :category_l1, :category_l2, :category_l3, :category_l4, :category_l5, :category_l6, :price, :special_price, :title, :serial_number, :brand, :quantity, :inventory_grade, :remarks, :description, :short_description

  def name
    object.item_description
  end

  # def city
  #   object.city_name
  # end

  def category_l1
    seller_category["category_l1"]
  end

  def category_l2
    seller_category["category_l2"]
  end

  def category_l3
    seller_category["category_l3"]
  end

  def category_l4
    seller_category["category_l4"]
  end

  def category_l5
    seller_category["category_l5"]
  end

  def category_l6
    seller_category["category_l6"]
  end

  def price
    object.item_price
  end

  def special_price
    object.item_price
  end

  def title
    object.item_description
  end

  def brand
    object.details["brand"]
  end

  def description
    object.item_description
  end

  def short_description
    object.item_description
  end

  def inventory_grade
    GradeMapping.find_by(client_item_name: object.grade)&.seller_item_name
  end

  def seller_category
    seller_category ||= object.client_category.seller_category.details
  end
end
