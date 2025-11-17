# frozen_string_literal: true

class ExtendedTimeEntriesController < ApplicationController
  before_action :authorize_global
  accept_api_auth :bulk_create

  def bulk_create
    unless api_request?
      render_error(status: 406, message: 'This endpoint only accepts API requests')
      return
    end

    entries_params = params[:time_entries] || []

    if entries_params.empty?
      respond_to do |format|
        format.api { render json: { errors: ['No time entries provided'] }, status: :unprocessable_entity }
      end
      return
    end

    created = []
    failed = []
    permission_failures = 0

    entries_params.each_with_index do |entry_params, index|
      # Determine project for permission check
      project = if entry_params[:issue_id]
                  Issue.find_by(id: entry_params[:issue_id])&.project
                elsif entry_params[:project_id]
                  Project.find_by(id: entry_params[:project_id])
                end

      # Check permission - user must be a member and have log_time permission
      is_member = project && User.current.member_of?(project)
      has_permission = is_member && User.current.allowed_to?(:log_time, project)

      unless has_permission
        failed << {
          index: index,
          errors: ['You do not have permission to log time on this project'],
        }
        permission_failures += 1
        next
      end

      time_entry = TimeEntry.new(
        issue_id: entry_params[:issue_id],
        project_id: entry_params[:project_id],
        spent_on: entry_params[:spent_on],
        hours: entry_params[:hours],
        activity_id: entry_params[:activity_id],
        comments: entry_params[:comments],
        user: User.current
      )

      # Set custom field values if provided
      if entry_params[:custom_field_values]
        time_entry.custom_field_values = entry_params[:custom_field_values]
      end

      if time_entry.save
        json = time_entry.as_json
        json['hours'] = time_entry.hours.to_f if time_entry.hours
        created << json
      else
        failed << {
          index: index,
          errors: time_entry.errors.full_messages,
        }
      end
    end

    # Determine HTTP status code
    status = if failed.empty?
               :created # All succeeded
             elsif created.empty? && permission_failures == failed.size
               :forbidden # All failed due to permission issues
             elsif created.empty?
               :unprocessable_entity # All failed due to validation
             else
               :multi_status # Partial success (207)
             end

    respond_to do |format|
      format.api do
        render json: {
          created: created,
          failed: failed,
          summary: {
            total: entries_params.size,
            created: created.size,
            failed: failed.size,
          },
        }, status: status
      end
    end
  end

  private

  def authorize_global
    # Check if user is logged in
    unless User.current.logged?
      if api_request?
        respond_to do |format|
          format.api { render json: { errors: ['Unauthorized'] }, status: :unauthorized }
        end
      else
        render_403
      end
      return false
    end

    # Check global permission for bulk time entry creation
    unless User.current.allowed_to_globally?(:bulk_create_time_entries)
      if api_request?
        respond_to do |format|
          format.api { render json: { errors: ['Forbidden - bulk_create_time_entries permission required'] }, status: :forbidden }
        end
      else
        render_403
      end
      return false
    end

    true
  end
end
