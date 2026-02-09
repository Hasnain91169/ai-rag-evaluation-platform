require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "sprockets/railtie"

Bundler.require(*Rails.groups)

module RagEvalPlatform
  class Application < Rails::Application
    config.load_defaults 7.1
    config.time_zone = "UTC"
    config.generators.system_tests = nil
    config.eager_load_paths << Rails.root.join("app/services")
  end
end
