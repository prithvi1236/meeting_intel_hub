module AuthHelpers
  DEFAULT_PASSWORD = "password12345"

  def sign_in_as(user, password: DEFAULT_PASSWORD)
    post session_path, params: { session: { email: user.email, password: password } }
  end
end
