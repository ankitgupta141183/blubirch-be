class Admin::RulesController < ApplicationController
	before_action :set_rule, only: [:show, :update, :destroy]

	def index
	 @rules = Rule.all

	 render json: @rules
	end

	def show
	 render json: @rule
	end

	def create
	  @rule = Rule.new(rule_params)

	  if @rule.save
	    render json: @rule, status: :created
	  else
	    render json: @rule.errors, status: :unprocessable_entity
	  end
	end

	def update
	  if @rule.update(rule_params)
	    render json: @rule
	  else
	    render json: @rule.errors, status: :unprocessable_entity
	  end
	end

	def destroy
	  @rule.destroy
	end

	def import 
	  @rules = Rule.import_disposition_rules(params[:file],params[:disposition_type])
	  render json: @rules
	end

	def import_client
	  @rules = Rule.import_client_disposition_rules(params[:file],params[:disposition_type])
	  render json: @rules
	end

	private
	
	def set_rule
	  @rule = Rule.find(params[:id])
	end

	def rule_params
	  params.require(:rule).permit(:name, :position, :rule_definition, :deleted_at)
	end

end
