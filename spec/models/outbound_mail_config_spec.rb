# frozen_string_literal: true

require "rails_helper"

RSpec.describe OutboundMailConfig do
  KEYS = %w[
    POSTMARK_API_TOKEN POSTMARK_SERVER_API_TOKEN SMTP_ADDRESS SMTP_PORT SMTP_DOMAIN
    SMTP_USER_NAME SMTP_PASSWORD SMTP_AUTHENTICATION SMTP_ENABLE_STARTTLS_AUTO
    RESEND_API_KEY RESEND_SHARED_FROM_EMAIL
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

  describe ".configure_resend_client!" do
    it "sets Resend.api_key when RESEND_API_KEY is set" do
      ENV["RESEND_API_KEY"] = "re_from_spec"
      described_class.configure_resend_client!
      expect(Resend.api_key).to eq("re_from_spec")
    end

    it "does not raise when RESEND_API_KEY is blank" do
      expect { described_class.configure_resend_client! }.not_to raise_error
    end
  end

  describe ".resend_fallback_configured?" do
    it "is true when RESEND_API_KEY is set" do
      ENV["RESEND_API_KEY"] = "re_xxx"
      expect(described_class.resend_fallback_configured?).to be true
    end

    it "is false when key missing" do
      expect(described_class.resend_fallback_configured?).to be false
    end
  end

  describe ".resend_fallback_ready_for_postmark?" do
    it "is true when both Postmark token and Resend key are set" do
      ENV["POSTMARK_API_TOKEN"] = "pm"
      ENV["RESEND_API_KEY"] = "re"
      expect(described_class.resend_fallback_ready_for_postmark?).to be true
    end

    it "is false when only Postmark is set" do
      ENV["POSTMARK_API_TOKEN"] = "pm"
      expect(described_class.resend_fallback_ready_for_postmark?).to be false
    end
  end

  describe ".resend_shared_from" do
    it "defaults to onboarding@resend.dev" do
      expect(described_class.resend_shared_from).to eq("onboarding@resend.dev")
    end

    it "reads RESEND_SHARED_FROM_EMAIL" do
      ENV["RESEND_SHARED_FROM_EMAIL"] = "custom@resend.dev"
      expect(described_class.resend_shared_from).to eq("custom@resend.dev")
    end
  end
end
