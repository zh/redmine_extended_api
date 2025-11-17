# frozen_string_literal: true

FactoryBot.define do
  factory :role do
    sequence(:name) { |n| "Role #{n}" }

    # Permissions need to be set after creation
    after(:build) do |role|
      role.permissions = [] if role.permissions.nil?
    end

    factory :role_with_log_time do
      after(:build) do |role|
        role.permissions = %i[log_time view_issues view_time_entries bulk_create_time_entries]
      end
    end

    factory :role_without_bulk_permission do
      after(:build) do |role|
        role.permissions = %i[log_time view_issues view_time_entries]
      end
    end
  end
end
