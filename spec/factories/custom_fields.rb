# frozen_string_literal: true

FactoryBot.define do
  factory :custom_field do
    sequence(:name) { |n| "Custom Field #{n}" }
    field_format { 'string' }

    factory :issue_custom_field, class: 'IssueCustomField' do
      type { 'IssueCustomField' }
    end

    factory :project_custom_field, class: 'ProjectCustomField' do
      type { 'ProjectCustomField' }
    end
  end
end
