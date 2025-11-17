# frozen_string_literal: true

FactoryBot.define do
  factory :issue do
    association :project
    association :tracker
    association :author, factory: :user
    association :status, factory: :issue_status
    association :priority, factory: :issue_priority
    sequence(:subject) { |n| "Issue #{n}" }
  end
end
