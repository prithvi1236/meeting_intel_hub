require "rails_helper"

RSpec.describe "Sessions", type: :request do
  describe "POST /session" do
    let!(:user) { create(:user, email: "member@example.com", password: AuthHelpers::DEFAULT_PASSWORD) }

    it "signs in and redirects to the root" do
      post session_path, params: {
        session: { email: "member@example.com", password: AuthHelpers::DEFAULT_PASSWORD }
      }
      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response).to have_http_status(:success)
    end

    it "rejects bad credentials" do
      post session_path, params: {
        session: { email: "member@example.com", password: "wrong-password" }
      }
      expect(response).to redirect_to(new_session_path)
    end
  end
end
