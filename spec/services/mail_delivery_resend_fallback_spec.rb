# frozen_string_literal: true

require "rails_helper"

RSpec.describe MailDeliveryResendFallback do
  describe ".enabled?" do
    it "is true when Postmark and Resend are configured and delivery_method is postmark" do
      allow(OutboundMailConfig).to receive_messages(
        postmark_configured?: true,
        resend_fallback_configured?: true
      )
      allow(ActionMailer::Base).to receive(:delivery_method).and_return(:postmark)
      expect(described_class.enabled?).to be true
    end

    it "is false when delivery_method is not postmark" do
      allow(OutboundMailConfig).to receive_messages(
        postmark_configured?: true,
        resend_fallback_configured?: true
      )
      allow(ActionMailer::Base).to receive(:delivery_method).and_return(:test)
      expect(described_class.enabled?).to be false
    end
  end

  describe ".deliver_now_with_fallback" do
    it "delegates to deliver_now when fallback is disabled" do
      allow(OutboundMailConfig).to receive(:postmark_configured?).and_return(false)
      md = instance_double(ActionMailer::MessageDelivery, deliver_now: true)
      expect(md).to receive(:deliver_now)
      described_class.deliver_now_with_fallback(md)
    end

    it "retries via Resend::Emails.send when Postmark raises" do
      allow(OutboundMailConfig).to receive_messages(
        postmark_configured?: true,
        resend_fallback_configured?: true,
        resend_shared_from: "onboarding@resend.dev",
        resend_api_key: "re_key"
      )
      allow(ActionMailer::Base).to receive(:delivery_method).and_return(:postmark)

      msg = Mail.new(from: "sender@example.com", to: "to@example.com", subject: "S") do
        text_part = Mail::Part.new do
          body "plain"
        end
        html_part = Mail::Part.new do
          content_type "text/html; charset=UTF-8"
          body "<p>hi</p>"
        end
        add_part text_part
        add_part html_part
      end

      md = instance_double(ActionMailer::MessageDelivery)
      allow(md).to receive(:message).and_return(msg)
      allow(md).to receive(:deliver_now).and_raise(Postmark::Error.new("Invalid From"))

      expect(Resend::Emails).to receive(:send).with(
        hash_including(
          from: /onboarding@resend\.dev/,
          to: [ "to@example.com" ],
          subject: "S",
          reply_to: "sender@example.com",
          text: "plain",
          html: "<p>hi</p>"
        )
      ).and_return({ "id" => "re_123" })

      described_class.deliver_now_with_fallback(md)
    end

    it "re-raises Postmark error when API key is missing" do
      allow(OutboundMailConfig).to receive_messages(
        postmark_configured?: true,
        resend_fallback_configured?: true,
        resend_api_key: nil
      )
      allow(ActionMailer::Base).to receive(:delivery_method).and_return(:postmark)

      msg = Mail.new(from: "x@y.com", to: "z@y.com", subject: "S", body: "B")
      md = instance_double(ActionMailer::MessageDelivery)
      allow(md).to receive(:message).and_return(msg)
      err = Postmark::Error.new("boom")
      allow(md).to receive(:deliver_now).and_raise(err)

      expect do
        described_class.deliver_now_with_fallback(md)
      end.to raise_error(Postmark::Error, "boom")
    end

    it "propagates Resend::Error when the API fails" do
      allow(OutboundMailConfig).to receive_messages(
        postmark_configured?: true,
        resend_fallback_configured?: true,
        resend_shared_from: "onboarding@resend.dev",
        resend_api_key: "re_key"
      )
      allow(ActionMailer::Base).to receive(:delivery_method).and_return(:postmark)

      msg = Mail.new(from: "a@b.com", to: "c@d.com", subject: "S", body: "text")
      md = instance_double(ActionMailer::MessageDelivery)
      allow(md).to receive(:message).and_return(msg)
      allow(md).to receive(:deliver_now).and_raise(Postmark::Error.new("pm"))

      allow(Resend::Emails).to receive(:send).and_raise(Resend::Error.new("resend down"))

      expect do
        described_class.deliver_now_with_fallback(md)
      end.to raise_error(Resend::Error, "resend down")
    end
  end
end
