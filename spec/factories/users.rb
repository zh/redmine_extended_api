# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    status { Principal::STATUS_ACTIVE }
    language { 'en' }
    password { 'password' }
    admin { false }
    firstname { 'Test' }
    sequence(:lastname) { |n| "User#{n}" }
    sequence(:mail) { |n| "user#{n}@example.com" }
    sequence(:login) { |n| "user#{n}" }

    factory :admin_user do
      admin { true }
      firstname { 'Admin' }
      lastname { 'User' }
    end
  end
end
