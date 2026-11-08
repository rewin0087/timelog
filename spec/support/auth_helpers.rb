module RequestAuthHelpers
  # Signs in through the real sessions endpoint so cookies behave as in the app.
  def sign_in(user, password: "password123")
    post session_path, params: { email_address: user.email_address, password: password }
  end

  def current_session_for(user) = user.sessions.order(:created_at).last

  def admin_sign_in(admin, password: "admin-password")
    post admin_session_path, params: { email_address: admin.email_address, password: password }
  end
end

module SystemAuthHelpers
  def sign_in_ui(user, password: "password123")
    visit new_session_path
    fill_in "Email", with: user.email_address
    fill_in "Password", with: password
    click_on "Sign in"
    expect(page).to have_css("aside.sidebar")
    wait_for_animations
  end

  # Cards slide/rise in with CSS and View Transition animations; wait for them before hovering or measuring.
  def wait_for_animations
    return if Capybara.current_driver == :rack_test

    Timeout.timeout(Capybara.default_max_wait_time) do
      sleep 0.05 until page.evaluate_script("document.getAnimations().every(a => a.playState !== 'running' || a.effect?.getTiming().iterations === Infinity)")
    end
  end
end

RSpec.configure do |config|
  config.include RequestAuthHelpers, type: :request
  config.include SystemAuthHelpers, type: :system
end
