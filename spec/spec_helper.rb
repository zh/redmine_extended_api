# frozen_string_literal: true

RSpec.configure do |config|
  Kernel.srand config.seed

  config.disable_monkey_patching!
  config.order = :random
  config.profile_examples = 10
  config.shared_context_metadata_behavior = :apply_to_host_groups
end
