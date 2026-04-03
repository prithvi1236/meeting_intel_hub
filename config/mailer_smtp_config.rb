# frozen_string_literal: true

# Builds outbound mail settings. Loaded from config/application.rb (before environments).
#
# Postmark: set POSTMARK_API_TOKEN or POSTMARK_SERVER_API_TOKEN. We use the Postmark HTTPS API
# (postmark-rails), not SMTP, so delivery works on hosts that block or time out to smtp.postmarkapp.com:587.
#
# Generic SMTP: set SMTP_ADDRESS, SMTP_USER_NAME, SMTP_PASSWORD, etc. (only when no Postmark token).
module MailerSmtpConfig
  module_function

  def postmark_api_token
    ENV["POSTMARK_API_TOKEN"].presence || ENV["POSTMARK_SERVER_API_TOKEN"].presence
  end

  def postmark_configured?
    postmark_api_token.present?
  end

  # Hash for config.action_mailer.postmark_settings when using Postmark API delivery.
  def build_postmark_settings
    return nil unless postmark_configured?

    { api_token: postmark_api_token }
  end

  # Hash for config.action_mailer.smtp_settings, or nil. Omits Postmark SMTP — use API instead.
  def build_smtp_settings
    return nil if postmark_configured?

    generic_smtp_settings
  end

  def smtp_configured?
    postmark_configured? || build_smtp_settings.present?
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
