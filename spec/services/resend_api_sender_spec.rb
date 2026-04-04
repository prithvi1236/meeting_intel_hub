# frozen_string_literal: true

require "rails_helper"

RSpec.describe ResendApiSender do
  describe ".build_params" do
    it "returns nil when there is no text or html body" do
      msg = Mail.new(from: "a@b.com", to: "c@d.com", subject: "S")
      expect(described_class.build_params(msg, envelope_from: "App <onboarding@resend.dev>")).to be_nil
    end

    it "builds params with text, html, and reply_to from original From" do
      msg = Mail.new(from: "sender@example.com", to: "to@example.com", subject: "Subj") do
        text_part = Mail::Part.new { body "plain" }
        html_part = Mail::Part.new do
          content_type "text/html; charset=UTF-8"
          body "<p>x</p>"
        end
        add_part text_part
        add_part html_part
      end

      h = described_class.build_params(msg, envelope_from: "App <onboarding@resend.dev>")
      expect(h[:from]).to eq("App <onboarding@resend.dev>")
      expect(h[:to]).to eq([ "to@example.com" ])
      expect(h[:subject]).to eq("Subj")
      expect(h[:text]).to eq("plain")
      expect(h[:html]).to eq("<p>x</p>")
      expect(h[:reply_to]).to eq("sender@example.com")
    end
  end

  describe ".deliver!" do
    it "raises when RESEND_API_KEY is missing" do
      allow(OutboundMailConfig).to receive(:resend_api_key).and_return(nil)
      expect do
        described_class.deliver!({ from: "x", to: [ "y" ], subject: "s" })
      end.to raise_error(ArgumentError, /RESEND_API_KEY/)
    end

    it "calls Resend::Emails.send and returns the response" do
      allow(OutboundMailConfig).to receive(:resend_api_key).and_return("re_key")
      allow(Resend::Emails).to receive(:send).and_return({ "id" => "abc" })

      result = described_class.deliver!(from: "f", to: [ "t" ], subject: "s")
      expect(result["id"]).to eq("abc")
      expect(Resend::Emails).to have_received(:send).with(hash_including(from: "f", to: [ "t" ], subject: "s"))
    end
  end
end
