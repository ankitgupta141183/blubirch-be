class Api::V1::ClientCategoriesController < ApplicationController

  def all_category_data
    @all_category = ClientCategory.all
    render json: @all_category
  end

  def get_test_rule
    @test_rule = ClientCategoryGradingRule.where(client_category_id: params[:client_category_id]).first.test_rule
    render json: @test_rule
  end

  def get_leaf_categories
    @all_childrens = []
    parents = ClientCategory.where("ancestry is null")
    parents.map{|p| @all_childrens << p.indirects.reject(&:has_children?)}
    render json: @all_childrens.flatten.to_json
  end

end
