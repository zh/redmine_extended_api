# frozen_string_literal: true

FactoryBot.define do
  factory :enumeration do
    sequence(:name) { |n| "Enumeration #{n}" }

    factory :issue_priority, class: 'IssuePriority' do
      type { 'IssuePriority' }
      is_default { false }
    end

    factory :time_entry_activity, class: 'TimeEntryActivity' do
      type { 'TimeEntryActivity' }
      is_default { false }
      active { true }
    end
  end
end
