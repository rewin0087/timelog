require "rails_helper"

RSpec.describe "Screen lock" do
  let(:user) { create(:user, auto_lock_minutes: 5) }

  context "without a lock code" do
    let(:user) { create(:user, :without_lock) }

    it "sends every page to lock setup" do
      sign_in(user)
      get time_entries_path
      expect(response).to redirect_to(edit_lock_settings_path)
    end

    it "answers non-HTML requests with 423" do
      sign_in(user)
      post heartbeat_lock_path, as: :json
      expect(response).to have_http_status(:locked)
    end
  end

  context "when unlocked" do
    before { sign_in(user) }

    it "serves pages with no-store caching and records activity" do
      current_session_for(user).update_column(:last_active_at, 1.minute.ago)
      get root_path
      expect(response).to have_http_status(:ok)
      expect(response.headers["Cache-Control"]).to eq("no-store")
      expect(current_session_for(user).last_active_at).to be_within(1.second).of(Time.current)
    end

    it "accepts heartbeats" do
      post heartbeat_lock_path, as: :json
      expect(response).to have_http_status(:no_content)
    end
  end

  context "when locked" do
    before do
      sign_in(user)
      current_session_for(user).lock!
    end

    it "redirects pages to the lock screen and remembers where you were" do
      get time_entries_path
      expect(response).to redirect_to(lock_path)
      delete lock_path, params: { pin: "2580" }
      expect(response).to redirect_to(time_entries_url)
    end

    it "blocks PDF exports and JSON calls with 423" do
      get export_report_path
      expect(response).to have_http_status(:locked)
      post heartbeat_lock_path, as: :json
      expect(response).to have_http_status(:locked)
    end

    it "still serves the daily inspiration" do
      get inspiration_path
      expect(response).to have_http_status(:ok)
    end
  end

  context "after the idle period" do
    it "locks on the next request, even if the browser never did" do
      sign_in(user)
      current_session_for(user).update_column(:last_active_at, 6.minutes.ago)
      get root_path
      expect(response).to redirect_to(lock_path)
      expect(current_session_for(user).locked_at).to be_present
    end
  end
end
