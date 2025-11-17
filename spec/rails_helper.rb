# frozen_string_literal: true

require 'rails_helper'
require_relative 'spec_helper'

ENV['RAILS_ENV'] ||= 'test'

abort('The Rails environment is running in production mode!') if Rails.env.production?

require 'rspec/rails'
require 'factory_bot_rails'

# Load support files
Dir[File.join(__dir__, 'support', '**', '*.rb')].each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  puts e.to_s.strip
  exit 1
end

RSpec.configure do |config|
  # Use Redmine's test fixtures from test/fixtures
  config.fixture_paths = [
    Rails.root.join('test/fixtures')
  ]

  config.use_transactional_fixtures = true

  # Infer spec type from file location
  config.infer_spec_type_from_file_location!

  # Filter Rails backtraces
  config.filter_rails_from_backtrace!

  # Enable REST API for tests
  config.before(:suite) do
    Setting.rest_api_enabled = '1'
  end

  # Reset User.current after each test to prevent state leakage
  config.after(:each, type: :controller) do
    User.current = nil
  end

  # Helper method for HTTP Basic authentication in API tests
  config.include Module.new {
    def credentials(user)
      {
        'HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Basic
          .encode_credentials(user.login, 'password')
      }
    end
  }, type: :controller
end
