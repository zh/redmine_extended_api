# frozen_string_literal: true

require_relative '../rails_helper'

RSpec.describe ExtendedQueriesController, type: :controller do
  let!(:admin) { create(:admin_user) }
  let!(:user) { create(:user) }
  let!(:other_user) { create(:user) }
  let!(:project) { create(:project) }
  let!(:role_with_manage_queries) do
    create(:role, permissions: %i[view_issues manage_public_queries])
  end

  before do
    request.headers.merge!(credentials(user))
  end

  describe 'POST #create' do
    context 'with private query' do
      it 'creates private issue query' do
        post :create, params: {
          query: {
            name: 'My Private Query',
            type: 'IssueQuery',
            visibility: Query::VISIBILITY_PRIVATE,
            filters: {
              'status_id' => { 'operator' => 'o', 'values' => [] },
            },
          },
          format: 'json',
        }

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['name']).to eq('My Private Query')
        expect(json['type']).to eq('IssueQuery')
        expect(json['visibility']).to eq(Query::VISIBILITY_PRIVATE)
        expect(json['user_id']).to eq(user.id)
        # Redmine normalizes filters - removes empty values arrays
        expect(json['filters']).to eq({ 'status_id' => { 'operator' => 'o' } })

        query = IssueQuery.find(json['id'])
        expect(query.name).to eq('My Private Query')
        expect(query.user).to eq(user)
      end
    end

    context 'with filters' do
      it 'creates query with due date filter' do
        post :create, params: {
          query: {
            name: 'Late Issues',
            type: 'IssueQuery',
            filters: {
              'due_date' => { 'operator' => '<=', 'values' => ['2025-05-01'] },
              'status_id' => { 'operator' => 'o', 'values' => [] },
            },
          },
          format: 'json',
        }

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['filters']['due_date']).to eq({ 'operator' => '<=', 'values' => ['2025-05-01'] })
      end
    end

    context 'with project' do
      it 'creates project-scoped query' do
        post :create, params: {
          query: {
            name: 'Project Query',
            type: 'IssueQuery',
            project_id: project.id,
          },
          format: 'json',
        }

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['project_id']).to eq(project.id)
      end
    end

    context 'with public visibility' do
      context 'when user has manage_public_queries permission' do
        before do
          create(:member, user: user, project: project, roles: [role_with_manage_queries])
        end

        it 'creates public project query' do
          post :create, params: {
            query: {
              name: 'Public Query',
              type: 'IssueQuery',
              project_id: project.id,
              visibility: Query::VISIBILITY_PUBLIC,
            },
            format: 'json',
          }

          expect(response).to have_http_status(:created)
          json = JSON.parse(response.body)
          expect(json['visibility']).to eq(Query::VISIBILITY_PUBLIC)
        end
      end

      context 'when user lacks manage_public_queries permission' do
        it 'returns forbidden' do
          post :create, params: {
            query: {
              name: 'Public Query',
              type: 'IssueQuery',
              project_id: project.id,
              visibility: Query::VISIBILITY_PUBLIC,
            },
            format: 'json',
          }

          expect(response).to have_http_status(:forbidden)
          json = JSON.parse(response.body)
          expect(json['errors']).to include('Insufficient permissions to create this query')
        end
      end

      context 'when admin creates global public query' do
        before do
          request.headers.merge!(credentials(admin))
        end

        it 'creates global public query' do
          post :create, params: {
            query: {
              name: 'Global Public Query',
              type: 'IssueQuery',
              visibility: Query::VISIBILITY_PUBLIC,
            },
            format: 'json',
          }

          expect(response).to have_http_status(:created)
          json = JSON.parse(response.body)
          expect(json['visibility']).to eq(Query::VISIBILITY_PUBLIC)
          expect(json['project_id']).to be_nil
        end
      end
    end

    context 'with column names and sort criteria' do
      it 'creates query with custom columns and sorting' do
        post :create, params: {
          query: {
            name: 'Custom Columns Query',
            type: 'IssueQuery',
            column_names: %w[id subject status priority],
            sort_criteria: [%w[due_date asc], %w[id desc]],
          },
          format: 'json',
        }

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['column_names']).to eq(%w[id subject status priority])
        # Redmine normalizes sort_criteria, just check it's present
        expect(json['sort_criteria']).to be_an(Array)
        expect(json['sort_criteria']).not_to be_empty
      end
    end

    context 'with invalid query type' do
      it 'returns unprocessable entity' do
        post :create, params: {
          query: {
            name: 'Invalid Query',
            type: 'InvalidQueryType',
          },
          format: 'json',
        }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to include('Unknown query type: InvalidQueryType')
      end
    end

    context 'with validation errors' do
      it 'returns validation errors' do
        post :create, params: {
          query: {
            type: 'IssueQuery',
            # Missing required name
          },
          format: 'json',
        }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).not_to be_empty
      end
    end

    context 'without API format' do
      it 'returns not acceptable' do
        post :create, params: {
          query: {
            name: 'Test Query',
            type: 'IssueQuery',
          },
        }

        expect(response).to have_http_status(:not_acceptable)
      end
    end
  end

  describe 'PUT #update' do
    let!(:query) { create(:issue_query, user: user) }
    let!(:other_query) { create(:issue_query, user: other_user) }

    context 'updating own private query' do
      it 'updates query name' do
        put :update, params: {
          id: query.id,
          query: {
            name: 'Updated Name',
          },
          format: 'json',
        }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['name']).to eq('Updated Name')

        query.reload
        expect(query.name).to eq('Updated Name')
      end

      it 'updates query filters' do
        put :update, params: {
          id: query.id,
          query: {
            filters: {
              'assigned_to_id' => { 'operator' => '=', 'values' => ['me'] },
            },
          },
          format: 'json',
        }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['filters']['assigned_to_id']).to eq({ 'operator' => '=', 'values' => ['me'] })
      end

      it 'updates query description' do
        put :update, params: {
          id: query.id,
          query: {
            description: 'New description',
          },
          format: 'json',
        }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['description']).to eq('New description')
      end
    end

    context 'updating another users query' do
      it 'returns forbidden' do
        put :update, params: {
          id: other_query.id,
          query: {
            name: 'Trying to update',
          },
          format: 'json',
        }

        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json['errors']).to include('Insufficient permissions to update this query')
      end
    end

    context 'when admin updates any query' do
      before do
        request.headers.merge!(credentials(admin))
      end

      it 'allows update' do
        put :update, params: {
          id: other_query.id,
          query: {
            name: 'Admin Updated',
          },
          format: 'json',
        }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['name']).to eq('Admin Updated')
      end
    end

    context 'with non-existent query' do
      it 'returns not found' do
        put :update, params: {
          id: 999_999,
          query: {
            name: 'Updated',
          },
          format: 'json',
        }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without API format' do
      it 'returns not acceptable' do
        put :update, params: {
          id: query.id,
          query: {
            name: 'Updated',
          },
        }

        expect(response).to have_http_status(:not_acceptable)
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:query) { create(:issue_query, user: user) }
    let!(:other_query) { create(:issue_query, user: other_user) }

    context 'deleting own private query' do
      it 'deletes the query' do
        expect do
          delete :destroy, params: {
            id: query.id,
            format: 'json',
          }
        end.to change(IssueQuery, :count).by(-1)

        expect(response).to have_http_status(:no_content)
        expect(IssueQuery.exists?(query.id)).to be false
      end
    end

    context 'deleting another users query' do
      it 'returns forbidden' do
        expect do
          delete :destroy, params: {
            id: other_query.id,
            format: 'json',
          }
        end.not_to change(IssueQuery, :count)

        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json['errors']).to include('Insufficient permissions to delete this query')
      end
    end

    context 'when admin deletes any query' do
      before do
        request.headers.merge!(credentials(admin))
      end

      it 'allows deletion' do
        expect do
          delete :destroy, params: {
            id: other_query.id,
            format: 'json',
          }
        end.to change(IssueQuery, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end

    context 'with non-existent query' do
      it 'returns not found' do
        delete :destroy, params: {
          id: 999_999,
          format: 'json',
        }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without API format' do
      it 'returns not acceptable' do
        delete :destroy, params: {
          id: query.id,
        }

        expect(response).to have_http_status(:not_acceptable)
      end
    end
  end

  describe 'authorization' do
    context 'when not authenticated' do
      before do
        request.env['HTTP_AUTHORIZATION'] = nil
      end

      it 'returns unauthorized for create' do
        post :create, params: {
          query: {
            name: 'Test',
            type: 'IssueQuery',
          },
          format: 'json',
        }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
