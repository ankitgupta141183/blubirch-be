class Api::V2::Warehouse::MarkdownsController < ApplicationController
  STATUS = "Pending Transfer Out Destination"

  before_action -> { set_pagination_params(params) }, only: :index
  before_action :filter_markdown_items, :search_markdown_items, only: [:index, :filter_categories, :filter_grade]

  def index
    @markdowns = @markdowns.includes([inventory: :client_category], :markdown_order).order('updated_at desc').page(@current_page).per(@per_page)
    render_collection(@markdowns, Api::V2::Warehouse::MarkdownSerializer)
  end

  def filter_categories
    @categories = get_categories.map{ |a| { id: a.first, name: a.last }}
    render json: { categories: @categories }
  end

  def filter_grade
    @grade = @markdowns.pluck(:grade).compact.uniq
    render json: { grade: @grade }
  end

  def get_distribution_center
    @distribution_center = DistributionCenter.where("site_category in (?)", ["A", "D", "B", "R"])
    render json: @distribution_center
  end

  private

  def search_markdown_items
    if params[:search_text].present?
      search_by_tag_number = @markdowns.where(tag_number: params[:search_text].split(',').collect(&:strip)&.flatten)
      search_by_article = @markdowns.search_by_text(params[:search_text].split(',').collect(&:strip)&.flatten)
      @markdowns = search_by_tag_number.present? ? search_by_tag_number : search_by_article
    end
  end

  def filter_markdown_items
    @markdowns = Markdown
    @markdowns = @markdowns.filter(params[:filter]) if params[:filter].present?
    @markdowns = @markdowns.where(is_active: true, status: self.class::STATUS)
  end

  def set_markdowns
    @markdowns = Markdown.includes(inventory: :client_category).where(id: params[:markdown][:ids])
  end

  def get_categories
    @markdowns.includes(inventory: :client_category).pluck("client_categories.id, client_categories.name").compact.uniq
  end
end
