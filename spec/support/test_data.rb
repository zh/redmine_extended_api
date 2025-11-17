# frozen_string_literal: true

# Helper to load Redmine's core fixtures needed for tests
RSpec.configure do |config|
  config.before(:suite) do
    # Load essential Redmine fixtures that all tests need
    # Note: NOT loading users - we create those with FactoryBot
    fixtures_to_load = %w[trackers issue_statuses enumerations roles]

    fixtures_to_load.each do |fixture_name|
      fixture_path = Rails.root.join('test', 'fixtures', "#{fixture_name}.yml")
      if File.exist?(fixture_path)
        ActiveRecord::FixtureSet.create_fixtures(Rails.root.join('test/fixtures'), fixture_name)
      end
    end
  end
end
