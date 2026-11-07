require "rails_helper"

RSpec.describe "Authentication" do
  let(:user) { create(:user) }

  describe "sign in" do
    it "shows the sign-in page" do
      get new_session_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Sign in")
    end

    it "signs in with the right password and starts a session" do
      expect { sign_in(user) }.to change(Session, :count).by(1)
      expect(response).to redirect_to(root_url)
      expect(cookies[:session_id]).to be_present
    end

    it "accepts the email in any case" do
      post session_path, params: { email_address: user.email_address.upcase, password: "password123" }
      expect(response).to redirect_to(root_url)
    end

    it "rejects a wrong password" do
      expect { sign_in(user, password: "wrong-password") }.not_to change(Session, :count)
      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to eq("Try another email address or password.")
    end

    it "returns to the page that asked for sign-in" do
      get time_entries_path
      expect(response).to redirect_to(new_session_path)
      sign_in(user)
      expect(response).to redirect_to(time_entries_url)
    end
  end

  describe "pages that need a session" do
    [ [ :get, "/" ], [ :get, "/time_entries" ], [ :get, "/time_entries/new" ], [ :get, "/reports" ],
      [ :get, "/reports/export" ], [ :get, "/invoices" ], [ :get, "/profile/edit" ], [ :get, "/lock_settings/edit" ],
      [ :post, "/today" ], [ :post, "/invoices" ], [ :patch, "/theme" ] ].each do |verb, path|
      it "redirects #{verb.upcase} #{path} to sign in" do
        send(verb, path)
        expect(response).to redirect_to(new_session_path)
      end
    end
  end

  describe "sign out" do
    it "ends the session, clears the cookie, and resets the skin" do
      sign_in(user)
      patch theme_path, params: { theme: "ocean" }
      expect { delete session_path }.to change(Session, :count).by(-1)
      expect(response).to redirect_to(new_session_path)
      expect(session[:theme]).to be_nil
      get root_path
      expect(response).to redirect_to(new_session_path)
    end
  end
end
