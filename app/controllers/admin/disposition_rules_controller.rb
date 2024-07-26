class Admin::DispositionRulesController < ApplicationController
	before_action :set_disposition_rule, only: [:show, :update, :destroy]

	def index
	 @disposition_rules = DispositionRule.all

	 render json: @disposition_rules
	end

	def show
	 render json: @disposition_rule
	end

	def create
	  @disposition_rule = DispositionRule.new(disposition_rule_params)

	  if @disposition_rule.save
	    render json: @disposition_rule, status: :created
	  else
	    render json: @disposition_rule.errors, status: :unprocessable_entity
	  end
	end

	def update
	  if @disposition_rule.update(disposition_rule_params)
	    render json: @disposition_rule
	  else
	    render json: @disposition_rule.errors, status: :unprocessable_entity
	  end
	end

	def destroy
	  @disposition_rule.destroy
	end

	private
	
	def set_disposition_rule
	  @disposition_rule = DispositionRule.find(params[:id])
	end

	def disposition_rule_params
	  params.require(:disposition_rule).permit(:name, :position, :disposition_rule_definition, :deleted_at)
	end

end
