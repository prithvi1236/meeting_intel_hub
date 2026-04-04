# frozen_string_literal: true

# Outbound email configuration. Loaded early from config/application.rb so
# config/environments/*.rb can call these helpers before Zeitwerk autoloads app/models.
#
# Three mutually exclusive setups for Action Mailer:
#
# 1. Postmark (recommended in production): POSTMARK_API_TOKEN — delivery via Postmark’s *HTTPS API*
#    (postmark-rails), not SMTP. No SMTP_ADDRESS involved.
#
# 2. Resend (optional): RESEND_API_KEY — used only as an *HTTPS API* fallback after Postmark::Error
#    (see ResendApiSender). Still not SMTP.
#
# 3. Generic SMTP (optional dev / alternate host): SMTP_ADDRESS (+ auth) — only when *no* Postmark
#    token is set. Examples: MailHog, corporate relay, providers without Postmark.
#
module OutboundMailConfig
  class << self
    def resend_api_key
      ENV["RESEND_API_KEY"].presence
    end

    # Sets Resend.api_key when RESEND_API_KEY is present (Resend HTTP API fallback).
    def configure_resend_client!
      key = resend_api_key
      return if key.blank?

      require "resend"
      Resend.api_key = key
    end

    def resend_fallback_configured?
      resend_api_key.present?
    end

    def resend_fallback_ready_for_postmark?
      postmark_configured? && resend_fallback_configured?
    end

    def resend_shared_from
      ENV.fetch("RESEND_SHARED_FROM_EMAIL", "onboarding@resend.dev")
    end

    def postmark_api_token
      ENV["POSTMARK_API_TOKEN"].presence || ENV["POSTMARK_SERVER_API_TOKEN"].presence
    end

    def postmark_configured?
      postmark_api_token.present?
    end

    def build_postmark_settings
      return nil unless postmark_configured?

      { api_token: postmark_api_token }
    end

    # ActionMailer :smtp settings, or nil. Unused when Postmark API is configured.
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
end
