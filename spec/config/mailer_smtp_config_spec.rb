# frozen_string_literal: true

require "rails_helper"

RSpec.describe MailerSmtpConfig do
  KEYS = %w[
    POSTMARK_API_TOKEN POSTMARK_SERVER_API_TOKEN SMTP_ADDRESS SMTP_PORT SMTP_DOMAIN
    SMTP_USER_NAME SMTP_PASSWORD SMTP_AUTHENTICATION SMTP_ENABLE_STARTTLS_AUTO
  ].freeze

  around do |example|
    backup = ENV.to_hash
    KEYS.each { |k| ENV.delete(k) }
    example.run
  ensure
    KEYS.each do |k|
      if backup.key?(k)
        ENV[k] = backup[k]
      else
        ENV.delete(k)
      end
    end
  end

  describe ".build_smtp_settings" do
    it "returns Postmark preset when POSTMARK_API_TOKEN is set" do
      ENV["POSTMARK_API_TOKEN"] = "pm-token-abc"
      ENV["SMTP_DOMAIN"] = "example.com"
      s = described_class.build_smtp_settings
      expect(s[:address]).to eq("smtp.postmarkapp.com")
      expect(s[:port]).to eq(587)
      expect(s[:user_name]).to eq("pm-token-abc")
      expect(s[:password]).to eq("pm-token-abc")
      expect(s[:authentication]).to eq(:plain)
      expect(s[:enable_starttls_auto]).to be true
      expect(s[:domain]).to eq("example.com")
    end

    it "accepts POSTMARK_SERVER_API_TOKEN" do
      ENV["POSTMARK_SERVER_API_TOKEN"] = "server-token"
      expect(described_class.build_smtp_settings[:user_name]).to eq("server-token")
    end

    it "prefers Postmark over generic SMTP when both are set" do
      ENV["POSTMARK_API_TOKEN"] = "pm-only"
      ENV["SMTP_ADDRESS"] = "smtp.other.com"
      ENV["SMTP_USER_NAME"] = "u"
      ENV["SMTP_PASSWORD"] = "p"
      expect(described_class.build_smtp_settings[:address]).to eq("smtp.postmarkapp.com")
    end

    it "returns generic SMTP when only SMTP_ADDRESS is set" do
      ENV["SMTP_ADDRESS"] = "smtp.example.com"
      ENV["SMTP_PORT"] = "465"
      ENV["SMTP_USER_NAME"] = "user"
      ENV["SMTP_PASSWORD"] = "secret"
      s = described_class.build_smtp_settings
      expect(s[:address]).to eq("smtp.example.com")
      expect(s[:port]).to eq(465)
      expect(s[:user_name]).to eq("user")
      expect(s[:password]).to eq("secret")
    end

    it "returns nil when nothing is configured" do
      expect(described_class.build_smtp_settings).to be_nil
    end
  end
end
