# frozen_string_literal: true

require "resend"

# Turns a rendered Mail::Message into Resend's JSON API and posts it (used after Postmark fails).
class ResendApiSender
  class << self
    # @return [Hash, nil] params for Resend::Emails.send, or nil if there is no text/html body
    def build_params(mail_message, envelope_from:)
      text, html = extract_plain_and_html(mail_message)
      return nil if text.blank? && html.blank?

      original_from = mail_message[:from]&.value
      params = {
        from: envelope_from,
        to: Array(mail_message.to).compact,
        subject: mail_message.subject.to_s
      }
      params[:text] = text if text.present?
      params[:html] = html if html.present?
      reply = reply_to_header(mail_message, original_from)
      params[:reply_to] = reply if reply.present?
      params
    end

    def deliver!(params)
      key = ::OutboundMailConfig.resend_api_key
      raise ArgumentError, "RESEND_API_KEY missing" if key.blank?

      Resend.api_key = key
      result = Resend::Emails.send(params)
      log_success(result)
      result
    rescue Resend::Error => e
      Rails.logger.error("[ResendApiSender] #{e.class}: #{e.message}")
      raise
    end

    private

    def extract_plain_and_html(msg)
      if msg.multipart?
        [ msg.text_part&.decoded, msg.html_part&.decoded ]
      elsif msg.mime_type.to_s.include?("html")
        [ nil, msg.body&.decoded ]
      else
        [ msg.body&.decoded, nil ]
      end
    end

    def reply_to_header(msg, original_from)
      return nil if original_from.blank?

      if msg.reply_to.present?
        [ original_from, msg[:reply_to].value ].compact.join(", ")
      else
        original_from
      end
    end

    def log_success(result)
      id = result[:id] || result["id"]
      Rails.logger.info("[ResendApiSender] sent id=#{id}") if id.present?
    end
  end
end
