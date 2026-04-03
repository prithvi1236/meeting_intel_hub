# frozen_string_literal: true

# Builds Action Mailer SMTP settings. Loaded from config/application.rb (before environments).
#
# Postmark: set POSTMARK_API_TOKEN (Server API token from Postmark). Username and password are both the token.
# Generic SMTP: set SMTP_ADDRESS, SMTP_USER_NAME, SMTP_PASSWORD, etc.
module MailerSmtpConfig
  module_function

  # Hash for config.action_mailer.smtp_settings, or nil if no outbound SMTP is configured.
  def build_smtp_settings
    token = postmark_api_token
    return postmark_smtp_settings(token) if token

    generic_smtp_settings
  end

  def smtp_configured?
    build_smtp_settings.present?
  end

  def postmark_api_token
    ENV["POSTMARK_API_TOKEN"].presence || ENV["POSTMARK_SERVER_API_TOKEN"].presence
  end

  def postmark_smtp_settings(token)
    {
      address: "smtp.postmarkapp.com",
      port: 587,
      user_name: token,
      password: token,
      authentication: :plain,
      enable_starttls_auto: true,
      domain: ENV.fetch("SMTP_DOMAIN", "localhost")
    }
  end

  def generic_smtp_settings
    address = ENV["SMTP_ADDRESS"].presence
    return nil unless address

    {
      address: address,
      port: ENV.fetch("SMTP_PORT", "587").to_i,
      domain: ENV.fetch("SMTP_DOMAIN", "localhost"),
      user_name: ENV["SMTP_USER_NAME"].presence,
      password: ENV["SMTP_PASSWORD"].presence,
      authentication: (ENV["SMTP_AUTHENTICATION"].presence || "plain").to_sym,
      enable_starttls_auto: !%w[false 0 no].include?(ENV["SMTP_ENABLE_STARTTLS_AUTO"].to_s.downcase)
    }.compact
  end
end
