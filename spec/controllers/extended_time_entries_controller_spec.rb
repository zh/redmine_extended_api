# frozen_string_literal: true

require_relative '../rails_helper'

RSpec.describe ExtendedTimeEntriesController, type: :controller do
  let(:role) { create(:role_with_log_time) }
  let(:user) { create(:user) }
  let(:user_without_permission) { create(:user) }
  let(:project) { create(:project) }
  let(:tracker) { project.trackers.first }
  let(:issue) { create(:issue, project: project, tracker: tracker) }
  let(:activity) { create(:time_entry_activity) }

  before do
    # Give user log_time permission on the project
    create(:member, user: user, project: project, roles: [role])
    request.headers.merge!(credentials(user))
  end

  describe 'POST #bulk_create' do
    context 'with all valid entries' do
      it 'creates all time entries' do
        post :bulk_create, params: {
          time_entries: [
            {
              issue_id: issue.id,
              spent_on: '2025-01-15',
              hours: 2.5,
              activity_id: activity.id,
              comments: 'Development work',
            },
            {
              issue_id: issue.id,
              spent_on: '2025-01-15',
              hours: 1.0,
              activity_id: activity.id,
              comments: 'Code review',
            },
          ],
          format: 'json',
        }

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)

        expect(json['summary']['total']).to eq(2)
        expect(json['summary']['created']).to eq(2)
        expect(json['summary']['failed']).to eq(0)
        expect(json['created'].size).to eq(2)
        expect(json['failed'].size).to eq(0)

        expect(json['created'][0]['hours']).to eq(2.5)
        expect(json['created'][1]['hours']).to eq(1.0)
      end
    end

    context 'with project_id' do
      it 'creates time entry for project' do
        post :bulk_create, params: {
          time_entries: [
            {
              project_id: project.id,
              spent_on: '2025-01-15',
              hours: 3.0,
              activity_id: activity.id,
              comments: 'Project meeting',
            },
          ],
          format: 'json',
        }

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)

        expect(json['summary']['created']).to eq(1)
        expect(json['created'][0]['project_id']).to eq(project.id)
      end
    end

    context 'with mixed valid and invalid entries' do
      it 'creates valid entries and reports invalid ones' do
        post :bulk_create, params: {
          time_entries: [
            {
              issue_id: issue.id,
              spent_on: '2025-01-15',
              hours: 2.0,
              activity_id: activity.id,
              comments: 'Valid entry',
            },
            {
              # Missing hours and activity_id
              issue_id: issue.id,
              spent_on: '2025-01-15',
              comments: 'Invalid entry',
            },
            {
              issue_id: issue.id,
              spent_on: '2025-01-15',
              hours: 1.5,
              activity_id: activity.id,
              comments: 'Another valid entry',
            },
          ],
          format: 'json',
        }

        expect(response).to have_http_status(:multi_status) # 207
        json = JSON.parse(response.body)

        expect(json['summary']['total']).to eq(3)
        expect(json['summary']['created']).to eq(2)
        expect(json['summary']['failed']).to eq(1)

        expect(json['failed'].size).to eq(1)
        expect(json['failed'][0]['index']).to eq(1)
        expect(json['failed'][0]['errors']).not_to be_empty
      end
    end

    context 'with all invalid entries' do
      it 'returns unprocessable entity' do
        post :bulk_create, params: {
          time_entries: [
            {
              issue_id: issue.id,
              spent_on: '2025-01-15',
              activity_id: activity.id,
              comments: 'Missing hours',
              # Missing hours - will fail validation
            },
            {
              issue_id: issue.id,
              spent_on: '2025-01-16',
              hours: -1.0,
              activity_id: activity.id,
              comments: 'Invalid hours',
              # Negative hours - will fail validation
            },
          ],
          format: 'json',
        }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)

        expect(json['summary']['total']).to eq(2)
        expect(json['summary']['created']).to eq(0)
        expect(json['summary']['failed']).to eq(2)
        expect(json['failed'].size).to eq(2)
      end
    end

    context 'with empty array' do
      it 'returns error' do
        post :bulk_create, params: {
          time_entries: [],
          format: 'json',
        }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors'].join).to include('No time entries provided')
      end
    end

    context 'without time_entries param' do
      it 'returns error' do
        post :bulk_create, params: { format: 'json' }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors'].join).to include('No time entries provided')
      end
    end

    context 'with different dates' do
      it 'creates entries for different dates' do
        post :bulk_create, params: {
          time_entries: [
            {
              issue_id: issue.id,
              spent_on: '2025-01-15',
              hours: 2.0,
              activity_id: activity.id,
              comments: 'Day 1',
            },
            {
              issue_id: issue.id,
              spent_on: '2025-01-16',
              hours: 3.0,
              activity_id: activity.id,
              comments: 'Day 2',
            },
          ],
          format: 'json',
        }

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)

        expect(json['summary']['created']).to eq(2)
        expect(Date.parse(json['created'][0]['spent_on'])).to eq(Date.parse('2025-01-15'))
        expect(Date.parse(json['created'][1]['spent_on'])).to eq(Date.parse('2025-01-16'))
      end
    end

    context 'sets current user' do
      it 'assigns time entry to current user' do
        post :bulk_create, params: {
          time_entries: [
            {
              issue_id: issue.id,
              spent_on: '2025-01-15',
              hours: 1.0,
              activity_id: activity.id,
              comments: 'Test',
            },
          ],
          format: 'json',
        }

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)

        created_entry = TimeEntry.find(json['created'][0]['id'])
        expect(created_entry.user_id).to eq(user.id)
      end
    end
  end

  describe 'authorization' do
    context 'when not authenticated' do
      before do
        request.env['HTTP_AUTHORIZATION'] = nil
      end

      it 'returns unauthorized' do
        post :bulk_create, params: {
          time_entries: [
            {
              issue_id: issue.id,
              spent_on: '2025-01-15',
              hours: 1.0,
              activity_id: activity.id,
            },
          ],
          format: 'json',
        }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'without log_time permission' do
      before do
        request.headers.merge!(credentials(user_without_permission))
      end

      it 'returns forbidden' do
        post :bulk_create, params: {
          time_entries: [
            {
              issue_id: issue.id,
              spent_on: '2025-01-15',
              hours: 1.0,
              activity_id: activity.id,
            },
          ],
          format: 'json',
        }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'without bulk_create_time_entries global permission' do
      let(:role_without_bulk) { create(:role_without_bulk_permission) }
      let(:user_without_bulk) { create(:user) }

      before do
        # User has log_time permission on project but not bulk_create_time_entries globally
        create(:member, user: user_without_bulk, project: project, roles: [role_without_bulk])
        request.headers.merge!(credentials(user_without_bulk))
      end

      it 'returns forbidden with specific error message' do
        post :bulk_create, params: {
          time_entries: [
            {
              issue_id: issue.id,
              spent_on: '2025-01-15',
              hours: 1.0,
              activity_id: activity.id,
            },
          ],
          format: 'json',
        }

        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json['errors']).to include('Forbidden - bulk_create_time_entries permission required')
      end
    end
  end

  describe 'API format requirement' do
    it 'requires API format' do
      post :bulk_create, params: {
        time_entries: [
          {
            issue_id: issue.id,
            spent_on: '2025-01-15',
            hours: 1.0,
            activity_id: activity.id,
          },
        ],
      }

      expect(response).to have_http_status(:not_acceptable)
    end
  end
end
