require "capybara/rspec"
require "capybara/cuprite"

Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(app, window_size: [ 1400, 1000 ], headless: ENV["HEADFUL"].blank?,
                                     process_timeout: 20, timeout: 10, js_errors: true,
                                     browser_options: { "no-sandbox" => nil })
end

Capybara.register_driver(:cuprite_mobile) do |app|
  Capybara::Cuprite::Driver.new(app, window_size: [ 390, 844 ], headless: ENV["HEADFUL"].blank?,
                                     process_timeout: 20, timeout: 10, js_errors: true,
                                     browser_options: { "no-sandbox" => nil })
end

Capybara.default_max_wait_time = 5
Capybara.server = :puma, { Silent: true }

RSpec.configure do |config|
  config.before(type: :system) { driven_by :rack_test }
  config.before(type: :system, js: true) { driven_by :cuprite }
  config.before(type: :system, mobile: true) { driven_by :cuprite_mobile }
end
