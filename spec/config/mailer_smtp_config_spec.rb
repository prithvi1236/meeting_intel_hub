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

  describe ".postmark_configured?" do
    it "is true when POSTMARK_API_TOKEN is set" do
      ENV["POSTMARK_API_TOKEN"] = "pm-token"
      expect(described_class.postmark_configured?).to be true
    end

    it "is true when POSTMARK_SERVER_API_TOKEN is set" do
      ENV["POSTMARK_SERVER_API_TOKEN"] = "server-token"
      expect(described_class.postmark_configured?).to be true
    end

    it "is false when no Postmark token" do
      expect(described_class.postmark_configured?).to be false
    end
  end

  describe ".build_postmark_settings" do
    it "returns api_token hash when POSTMARK_API_TOKEN is set" do
      ENV["POSTMARK_API_TOKEN"] = "pm-token-abc"
      expect(described_class.build_postmark_settings).to eq(api_token: "pm-token-abc")
    end

    it "returns nil when no Postmark token" do
      expect(described_class.build_postmark_settings).to be_nil
    end
  end

  describe ".build_smtp_settings" do
    it "returns nil when Postmark is configured (Postmark uses HTTPS API, not SMTP)" do
      ENV["POSTMARK_API_TOKEN"] = "pm-only"
      ENV["SMTP_ADDRESS"] = "smtp.other.com"
      ENV["SMTP_USER_NAME"] = "u"
      ENV["SMTP_PASSWORD"] = "p"
      expect(described_class.build_smtp_settings).to be_nil
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
