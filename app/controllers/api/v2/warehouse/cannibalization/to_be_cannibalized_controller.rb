class Api::V2::Warehouse::Cannibalization::ToBeCannibalizedController < Api::V2::Warehouse::CannibalizationsController
  STATUS = 'To Be Cannibalized'

  include GenerateTagNumber

  before_action :check_for_update_quantity_params, only: :update_quantity
  before_action :set_cannibalization, only: [:move_to_work_in_progress, :move_to_cannibalized]
  before_action :validate_cannibalization_params, only: [:move_to_work_in_progress]

  def generate_tag_number
    render json: { new_tag_number: generate_uniq_tag_number }
  end

  def move_to_cannibalized
    begin
      moved_items_count = ActiveRecord::Base.transaction do
        @cannibalization.move_to_cannibalized_tab(current_user)
      end
      render_success_message("#{moved_items_count.size} item(s) are moved to 'Cannibalized'", :ok)
    rescue => e
      render_error(e.message, 500)
    end
  end

  def move_to_work_in_progress
    begin
      ActiveRecord::Base.transaction do
        @sub_cannibalize_item.move_to_work_in_progress_tab(params[:to_be_cannibalized], @sub_cannibalize_item_child, current_user)
      end
      render_success_message(params.dig(:to_be_cannibalized, :condition) == 'Write Off' ? 'Scanned article id write off has been done.' : "Item moved to 'Work In Progress'", :ok)
    rescue => e
      render_error(e.message, 500)
    end
  end

  private

  def check_for_update_quantity_params
    required_params = [:id, :quantity, :condition]

    required_params.each do |param|
      render_error("Required param \"#{param.to_s}\" is missing!", 422) and return if params[param].blank?
    end
  end

  def validate_cannibalization_params
    errors = []
    errors.push('Data for cannibalization not present in params.') unless params[:to_be_cannibalized].present?
    errors.push("Quantity \"#{params.dig(:to_be_cannibalized, :quantity).to_i}\" not a valid value.") if params.dig(:to_be_cannibalized, :quantity).to_i.zero?
    @sub_cannibalize_item = Cannibalization.unscoped.find_by(id: params[:to_be_cannibalized].delete(:id), parent_id: @cannibalization.id)
    if @sub_cannibalize_item.present?
      errors.push("Tag ID \"#{params.dig(:to_be_cannibalized, :tag_id)}\" is already present.") if params.dig(:to_be_cannibalized, :tag_id).present? && !@sub_cannibalize_item.validate_tag_uniqueness(params.dig(:to_be_cannibalized, :tag_id).to_s)
      @sub_cannibalize_item_child = Cannibalization.unscoped.find_by("details ->> 'old_cannibalization_id' = '?' ", @sub_cannibalize_item.id)
      errors.push("Quantity \"#{params.dig(:to_be_cannibalized, :quantity)}\" not available for Article ID \"#{params.dig(:to_be_cannibalized, :article_id)}\" and UOM \"#{params.dig(:to_be_cannibalized, :uom)}\".") unless (@sub_cannibalize_item.try(:quantity).to_i + @sub_cannibalize_item_child.try(:quantity).to_i) >= params.dig(:to_be_cannibalized, :quantity).to_i
    else
      errors.push('Scanned item not found.')
    end
    render_error(errors.join(' '), 422) if errors.any?
  end
end
