# frozen_string_literal: true

class ExtendedQueriesController < ApplicationController
  before_action :require_login
  before_action :find_query, only: %i[update destroy]
  accept_api_auth :create, :update, :destroy

  def create
    unless api_request?
      render_error(status: 406, message: 'This endpoint only accepts API requests')
      return
    end

    query_params_hash = params[:query] || {}
    query_type = query_params_hash[:type] || 'IssueQuery'

    # Validate and get the query class
    begin
      klass = query_type.constantize
      unless klass < Query
        respond_to do |format|
          format.api { render json: { errors: ['Invalid query type'] }, status: :unprocessable_entity }
        end
        return
      end
    rescue NameError
      respond_to do |format|
        format.api { render json: { errors: ["Unknown query type: #{query_type}"] }, status: :unprocessable_entity }
      end
      return
    end

    @query = klass.new
    @query.user = User.current
    @query.project_id = query_params_hash[:project_id] if query_params_hash[:project_id]

    update_query_attributes

    # Check permissions
    unless can_manage_query?(@query)
      respond_to do |format|
        format.api { render json: { errors: ['Insufficient permissions to create this query'] }, status: :forbidden }
      end
      return
    end

    if @query.save
      respond_to do |format|
        format.api { render json: query_to_json(@query), status: :created }
      end
    else
      respond_to do |format|
        format.api { render json: { errors: @query.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def update
    unless api_request?
      render_error(status: 406, message: 'This endpoint only accepts API requests')
      return
    end

    update_query_attributes

    # Check permissions
    unless can_manage_query?(@query)
      respond_to do |format|
        format.api { render json: { errors: ['Insufficient permissions to update this query'] }, status: :forbidden }
      end
      return
    end

    if @query.save
      respond_to do |format|
        format.api { render json: query_to_json(@query), status: :ok }
      end
    else
      respond_to do |format|
        format.api { render json: { errors: @query.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    unless api_request?
      render_error(status: 406, message: 'This endpoint only accepts API requests')
      return
    end

    # Check permissions
    unless can_manage_query?(@query)
      respond_to do |format|
        format.api { render json: { errors: ['Insufficient permissions to delete this query'] }, status: :forbidden }
      end
      return
    end

    if @query.destroy
      respond_to do |format|
        format.api { head :no_content }
      end
    else
      respond_to do |format|
        format.api { render json: { errors: ['Cannot delete query'] }, status: :unprocessable_entity }
      end
    end
  end

  private

  def find_query
    @query = Query.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def update_query_attributes
    query_params_hash = params[:query] || {}

    @query.name = query_params_hash[:name] if query_params_hash[:name]
    @query.description = query_params_hash[:description] if query_params_hash.key?(:description)

    # Set visibility
    if query_params_hash.key?(:visibility)
      @query.visibility = query_params_hash[:visibility].to_i
    end

    # Set project - nil means global query
    if query_params_hash.key?(:project_id)
      @query.project_id = query_params_hash[:project_id]
    end

    # Set filters
    if query_params_hash.key?(:filters)
      @query.filters = query_params_hash[:filters]
    end

    # Set column names
    if query_params_hash.key?(:column_names)
      @query.column_names = query_params_hash[:column_names]
    end

    # Set sort criteria
    if query_params_hash.key?(:sort_criteria)
      @query.sort_criteria = query_params_hash[:sort_criteria]
    end

    # Set roles (for visibility = VISIBILITY_ROLES)
    return unless query_params_hash.key?(:role_ids)

    @query.role_ids = query_params_hash[:role_ids]
  end

  def can_manage_query?(query)
    # User can manage their own private queries
    return true if query.is_private? && query.user_id == User.current.id

    # Admin can manage all queries
    return true if User.current.admin?

    # For public/role queries, need manage_public_queries permission
    if query.visibility != Query::VISIBILITY_PRIVATE
      return false if query.is_global? # Only admins can manage global public queries

      return User.current.allowed_to?(:manage_public_queries, query.project)
    end

    false
  end

  def query_to_json(query)
    {
      id: query.id,
      name: query.name,
      description: query.description,
      type: query.type,
      project_id: query.project_id,
      user_id: query.user_id,
      visibility: query.visibility,
      is_public: query.is_public?,
      filters: query.filters,
      column_names: query.column_names,
      sort_criteria: query.sort_criteria,
    }
  end
end
