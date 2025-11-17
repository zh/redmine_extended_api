# frozen_string_literal: true

FactoryBot.define do
  factory :issue_query, class: 'IssueQuery' do
    sequence(:name) { |n| "Test Query #{n}" }
    user
    visibility { Query::VISIBILITY_PRIVATE }

    after(:build) do |query|
      query.filters = {} if query.filters.nil?
    end

    factory :public_issue_query do
      visibility { Query::VISIBILITY_PUBLIC }
    end

    factory :roles_issue_query do
      visibility { Query::VISIBILITY_ROLES }
      after(:create) do |query|
        query.roles << create(:role) if query.roles.empty?
      end
    end

    factory :project_issue_query do
      project
    end

    factory :issue_query_with_filters do
      after(:build) do |query|
        query.filters = {
          'status_id' => { 'operator' => 'o', 'values' => [] },
        }
      end
    end
  end
end
