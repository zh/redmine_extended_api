# frozen_string_literal: true

FactoryBot.define do
  factory :project do
    sequence(:name) { |n| "Project #{n}" }
    sequence(:identifier) { |n| "project-#{n}" }

    after(:build) do |project|
      project.trackers = Tracker.limit(3) if project.trackers.empty?
      project.enabled_module_names = %w[issue_tracking time_tracking]
    end
  end
end
