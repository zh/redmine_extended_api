# frozen_string_literal: true

FactoryBot.define do
  factory :tracker do
    sequence(:name) { |n| "Tracker #{n}" }
    default_status { IssueStatus.first || association(:issue_status) }
  end
end
