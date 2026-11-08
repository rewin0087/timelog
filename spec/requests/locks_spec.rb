require "rails_helper"

RSpec.describe "Locks" do
  let(:user) { create(:user) }
  let(:session_record) { current_session_for(user) }

  before { sign_in(user) }

  describe "GET /lock" do
    it "redirects home when not locked" do
      get lock_path
      expect(response).to redirect_to(root_url)
    end

    it "shows the lock screen when locked" do
      session_record.lock!
      get lock_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Screen locked", user.name)
    end

    it "sends users without a code to onboarding" do
      user.update_column(:lock_pin_digest, nil)
      get lock_path
      expect(response).to redirect_to(onboarding_path)
    end
  end

  describe "POST /lock" do
    it "locks the session (HTML)" do
      post lock_path
      expect(response).to redirect_to(lock_path)
      expect(session_record.reload.locked_at).to be_present
    end

    it "locks the session (JSON)" do
      post lock_path, as: :json
      expect(response).to have_http_status(:no_content)
      expect(session_record.reload).to be_locked
    end
  end

  describe "DELETE /lock" do
    before { session_record.lock! }

    it "unlocks with the right code" do
      delete lock_path, params: { pin: "2580" }
      expect(response).to redirect_to(root_url)
      expect(session_record.reload.locked_at).to be_nil
    end

    it "rejects a wrong code and says how many attempts are left" do
      delete lock_path, params: { pin: "1111" }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Wrong code. 4 attempts left")
      expect(session_record.reload).to be_locked
    end

    it "signs out after 5 wrong codes" do
      4.times { delete lock_path, params: { pin: "1111" } }
      expect(response.body).to include("1 attempt left")
      expect { delete lock_path, params: { pin: "1111" } }.to change(Session, :count).by(-1)
      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to include("Too many wrong codes")
    end

    it "redirects when already unlocked" do
      session_record.unlock!
      delete lock_path, params: { pin: "0000" }
      expect(response).to redirect_to(root_url)
    end
  end
end
