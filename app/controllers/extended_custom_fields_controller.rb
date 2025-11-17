# frozen_string_literal: true

class ExtendedCustomFieldsController < ApplicationController
  before_action :require_admin
  before_action :find_custom_field, only: [:update, :destroy]
  accept_api_auth :create, :update, :destroy

  def create
    unless api_request?
      render_error(status: 406, message: 'This endpoint only accepts API requests')
      return
    end

    cf_params = params[:custom_field] || {}
    type_name = cf_params[:type] || 'IssueCustomField'

    # Validate and get the custom field class
    begin
      klass = type_name.constantize
      unless klass < CustomField
        respond_to do |format|
          format.api { render json: {errors: ['Invalid custom field type']}, status: :unprocessable_entity }
        end
        return
      end
    rescue NameError
      respond_to do |format|
        format.api { render json: {errors: ["Unknown custom field type: #{type_name}"]}, status: :unprocessable_entity }
      end
      return
    end

    @custom_field = klass.new(custom_field_params)

    if @custom_field.save
      respond_to do |format|
        format.api { render json: @custom_field.as_json, status: :created }
      end
    else
      respond_to do |format|
        format.api { render json: {errors: @custom_field.errors.full_messages}, status: :unprocessable_entity }
      end
    end
  end

  def update
    unless api_request?
      render_error(status: 406, message: 'This endpoint only accepts API requests')
      return
    end

    if @custom_field.update(custom_field_params)
      respond_to do |format|
        format.api { render json: @custom_field.as_json, status: :ok }
      end
    else
      respond_to do |format|
        format.api { render json: {errors: @custom_field.errors.full_messages}, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    unless api_request?
      render_error(status: 406, message: 'This endpoint only accepts API requests')
      return
    end

    if @custom_field.destroy
      respond_to do |format|
        format.api { head :no_content }
      end
    else
      respond_to do |format|
        format.api { render_api_errors(['Cannot delete custom field - it may be in use']) }
      end
    end
  end

  private

  def find_custom_field
    @custom_field = CustomField.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def custom_field_params
    params.require(:custom_field).permit(
      :name, :field_format, :is_required, :is_for_all, :default_value,
      :min_length, :max_length, :regexp, :multiple, :visible, :searchable,
      :description, :editable, tracker_ids: [], possible_values: [], project_ids: [],
      role_ids: []
    )
  end
end
