require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"
require "webmock/rspec"

# Never call the real FuelIX API from tests (dotenv may have loaded a real key from .env).
ENV.delete("FUELIX_API_KEY")
WebMock.disable_net_connect!(allow_localhost: true)

Rails.root.glob("spec/support/**/*.rb").sort.each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.fixture_paths = [ Rails.root.join("spec/fixtures") ]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods
  config.include ActiveSupport::Testing::TimeHelpers

  # Every example runs on a fixed day so month/weekday maths is predictable:
  # Friday 13 November 2026 (November 2026 has 21 weekdays -> 7.6190h per day).
  config.around do |example|
    travel_to(example.metadata.fetch(:at, Time.zone.local(2026, 11, 13, 10, 0, 0))) { example.run }
  end
end
