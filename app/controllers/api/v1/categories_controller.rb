class Api::V1::CategoriesController < ApplicationController

  def test_rules
    @test_rules = TestRule.all
    render json: @test_rules
  end

  def grading_rules
    @grading_rules = GradingRule.all
    render json: @grading_rules
  end

  def client_category_grading_rules
    @client_category_grading_rules = ClientCategoryGradingRule.all
    render json: @client_category_grading_rules
  end

	def all_category
    @all_category = ClientCategory.all.uniq
    render json: @all_category
  end

  def parent_category
    @all_category = ClientCategory.roots
    render json: @all_category
  end

  def leaf_category
    @leaf_category = []
    parent_category = ClientCategory.roots
    desc_cat = []
    parent_category.each do |cat|
      desc_cat << cat.descendants
    end
    desc_cat = desc_cat.flatten
    desc_cat.each do |leaf|
      if leaf.is_childless? && leaf.present?
        @leaf_category << leaf
      end
    end
    render json: @leaf_category
  end

  def get_details
    @leaf_category = ClientCategory.find(params[:id])
    render json: @leaf_category
  end

  def attribute_types
    @attribute_master = AttributeMaster.pluck(:attr_type).uniq
    render json: @attribute_master
  end

  def attribute_reasons
    @attribute_master = AttributeMaster.pluck(:reason).uniq
    render json: @attribute_reasons
  end

  def attribute_label
    @attribute_master = AttributeMaster.pluck(:attr_label).uniq
    render json: @attribute_reasons
  end

  def attribute_label
    @attribute_master = AttributeMaster.pluck(:field_type).uniq
    render json: @attribute_reasons
  end

end
