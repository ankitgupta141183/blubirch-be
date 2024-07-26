class Admin::AlertConfigurationsController < ApplicationController

  before_action :alert_configuration, only: [:show, :edit, :update, :destroy]

	def index
    set_pagination_params(params)
		# @alert_configurations = AlertConfiguration.filter(filtering_params).page(@current_page).per(@per_page)
 		@alert_configurations = AlertConfiguration.all.page(@current_page).per(@per_page)
 		render json: @alert_configurations, meta: pagination_meta(@alert_configurations)
	end

 	def show
   render json: @alert_configuration
 	end

 	def create
 		lookup_value = LookupValue.where(code: params['configuration']['code'] ).last
	  if lookup_value.present? 
		  @alert_configuration = AlertConfiguration.new(alert_type_id: lookup_value.id)
		  if @alert_configuration.save
		    render json: @alert_configuration, status: :created
		  else
		    render json: @alert_configuration.errors, status: :unprocessable_entity
		  end
		else
			render json: "Wrong Parameters", status: :unprocessable_entity
		end
	end

	def import
		AlertConfiguration.import(params["file"],params["distribution_center_id"])
	end

	def edit
    render json: @alert_configuration
  end

	def update
		lookup_value = LookupValue.where(code: params['configuration']['code'] ).last
	  if lookup_value.present?
		  if @alert_configuration.update(alert_type_id: lookup_value.id)
		    render json: @alert_configuration
		  else
		    render json: @alert_configuration.errors, status: :unprocessable_entity
		  end
		else
			render json: "Wrong Parameters", status: :unprocessable_entity
		end
	end


	def destroy
	  @alert_configuration.destroy
	end

  private

	def alert_configuration
	 @alert_configuration = AlertConfiguration.find(params[:id])
	end

	# def alert_configuration_params
	#  params.require(:alert_configuration).permit(:alert_type)
	# end

	# def filtering_params
 #    params.slice(:name, :code, :ancestry)
 #  end

end
