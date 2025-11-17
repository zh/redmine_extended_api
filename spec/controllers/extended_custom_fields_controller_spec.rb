# frozen_string_literal: true

require_relative '../rails_helper'

RSpec.describe ExtendedCustomFieldsController, type: :controller do
  let!(:admin) { create(:admin_user) }
  let!(:user) { create(:user) }

  before do
    request.headers.merge!(credentials(admin))
  end

  describe 'POST #create' do
    context 'with string format' do
      it 'creates issue custom field' do
        post :create, params: {
          custom_field: {
            type: 'IssueCustomField',
            name: 'Customer Name',
            field_format: 'string',
            is_required: false,
            is_for_all: true
          },
          format: 'json'
        }

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['name']).to eq('Customer Name')
        expect(json['field_format']).to eq('string')

        cf = CustomField.find(json['id'])
        expect(cf.type).to eq('IssueCustomField')
        expect(cf.name).to eq('Customer Name')
      end
    end

    context 'with list format' do
      it 'creates custom field with possible values' do
        post :create, params: {
          custom_field: {
            type: 'IssueCustomField',
            name: 'Priority Level',
            field_format: 'list',
            possible_values: %w[Low Medium High Critical],
            is_required: true,
            is_for_all: true
          },
          format: 'json'
        }

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['name']).to eq('Priority Level')
        expect(json['field_format']).to eq('list')
        expect(json['is_required']).to be true

        cf = CustomField.find(json['id'])
        expect(cf.possible_values).to eq(%w[Low Medium High Critical])
      end
    end

    context 'with project custom field type' do
      it 'creates project custom field' do
        post :create, params: {
          custom_field: {
            type: 'ProjectCustomField',
            name: 'Project Code',
            field_format: 'string',
            is_required: false
          },
          format: 'json'
        }

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        cf = CustomField.find(json['id'])
        expect(cf.type).to eq('ProjectCustomField')
      end
    end

    context 'with invalid type' do
      it 'returns error' do
        post :create, params: {
          custom_field: {
            type: 'InvalidCustomField',
            name: 'Test',
            field_format: 'string'
          },
          format: 'json'
        }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors'].join).to include('Unknown custom field type')
      end
    end

    context 'with non-custom field type' do
      it 'returns error' do
        post :create, params: {
          custom_field: {
            type: 'Project',
            name: 'Test',
            field_format: 'string'
          },
          format: 'json'
        }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors'].join).to include('Invalid custom field type')
      end
    end

    context 'when name is missing' do
      it 'returns validation error' do
        post :create, params: {
          custom_field: {
            type: 'IssueCustomField',
            field_format: 'string'
          },
          format: 'json'
        }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors'].any? { |e| e.include?('Name') }).to be true
      end
    end

    context 'with tracker IDs' do
      it 'creates custom field for specific trackers' do
        tracker_ids = Tracker.limit(2).pluck(:id)

        post :create, params: {
          custom_field: {
            type: 'IssueCustomField',
            name: 'Tracker Specific',
            field_format: 'string',
            tracker_ids: tracker_ids
          },
          format: 'json'
        }

        expect(response).to have_http_status(:created)
        cf = CustomField.find(JSON.parse(response.body)['id'])
        expect(cf.tracker_ids.sort).to eq(tracker_ids.sort)
      end
    end
  end

  describe 'PUT #update' do
    let(:custom_field) { IssueCustomField.create!(name: 'Original Name', field_format: 'string') }

    context 'updating name' do
      it 'updates the custom field name' do
        put :update, params: {
          id: custom_field.id,
          custom_field: { name: 'Updated Name' },
          format: 'json'
        }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['name']).to eq('Updated Name')

        custom_field.reload
        expect(custom_field.name).to eq('Updated Name')
      end
    end

    context 'updating properties' do
      let(:list_field) do
        IssueCustomField.create!(
          name: 'Test Field',
          field_format: 'list',
          possible_values: %w[A B C]
        )
      end

      it 'updates custom field properties' do
        put :update, params: {
          id: list_field.id,
          custom_field: {
            is_required: true,
            possible_values: %w[A B C D E]
          },
          format: 'json'
        }

        expect(response).to have_http_status(:ok)
        list_field.reload
        expect(list_field.is_required).to be true
        expect(list_field.possible_values).to eq(%w[A B C D E])
      end
    end

    context 'when custom field not found' do
      it 'returns not found error' do
        put :update, params: {
          id: 99999,
          custom_field: { name: 'Test' },
          format: 'json'
        }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'DELETE #destroy' do
    let(:custom_field) { IssueCustomField.create!(name: 'To Delete', field_format: 'string') }

    context 'deleting custom field' do
      it 'deletes the custom field' do
        cf_id = custom_field.id

        delete :destroy, params: { id: custom_field.id, format: 'json' }

        expect(response).to have_http_status(:no_content)
        expect(CustomField.find_by(id: cf_id)).to be_nil
      end
    end

    context 'when custom field not found' do
      it 'returns not found error' do
        delete :destroy, params: { id: 99999, format: 'json' }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'authorization' do
    before do
      request.headers.merge!(credentials(user))
    end

    it 'requires admin for create' do
      post :create, params: {
        custom_field: {
          type: 'IssueCustomField',
          name: 'Test',
          field_format: 'string'
        },
        format: 'json'
      }

      expect(response).to have_http_status(:forbidden)
    end

    it 'requires admin for update' do
      cf = IssueCustomField.create!(name: 'Test', field_format: 'string')

      put :update, params: {
        id: cf.id,
        custom_field: { name: 'Updated' },
        format: 'json'
      }

      expect(response).to have_http_status(:forbidden)
    end

    it 'requires admin for destroy' do
      cf = IssueCustomField.create!(name: 'Test', field_format: 'string')

      delete :destroy, params: { id: cf.id, format: 'json' }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'API format requirement' do
    it 'requires API format for create' do
      post :create, params: {
        custom_field: {
          type: 'IssueCustomField',
          name: 'Test',
          field_format: 'string'
        }
      }

      expect(response).to have_http_status(:not_acceptable)
    end
  end
end
