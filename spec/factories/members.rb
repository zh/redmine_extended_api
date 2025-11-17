# frozen_string_literal: true

FactoryBot.define do
  factory :member do
    association :user
    association :project

    transient do
      roles { [] }
    end

    before(:create) do |member, evaluator|
      # Set role_ids before validation
      if evaluator.roles.any?
        # Ensure roles are persisted first
        role_ids = evaluator.roles.map do |r|
          r.persisted? ? r.id : r.save! && r.id
        end
        member.role_ids = role_ids
      end
    end
  end
end
