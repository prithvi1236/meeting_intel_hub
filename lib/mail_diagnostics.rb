# frozen_string_literal: true

# Dev/ops helper for bin/rails mail:diag — keeps the rake task thin.
class MailDiagnostics
  def self.run(io = $stdout)
    new(io).run
  end

  def initialize(io)
    @out = io
  end

  def run
    line "=== Meeting Intel — mail:diag ==="
    generic_smtp = ::OutboundMailConfig.build_smtp_settings
    line summarize_outbound_config(generic_smtp)
    line
    line "--- Action Mailer (RAILS_ENV=#{Rails.env}) ---"
    line "delivery_method: #{ActionMailer::Base.delivery_method}"
    line recent_tmp_mail_summary
    line
    line "--- Active Job ---"
    line "Adapter: #{ActiveJob::Base.queue_adapter.class.name}"
    line "Follow-up email: sent inside FollowupSendJob (deliver_now); no separate mailers queue needed."
    line "Tip: follow-ups need a worker unless DEV_INLINE_JOBS=1 (see .env.example)."
    line
    line "--- FollowupDraft ---"
    line FollowupDraft.group(:status).count.inspect
    confirmed = FollowupDraft.where(status: :confirmed)
    line "Confirmed (queued in UI): #{confirmed.count}"
    confirmed.limit(5).find_each { |d| line "  id=#{d.id} updated_at=#{d.updated_at}" }
    line
    line followup_send_job_summary
    line
    line "--- Generic SMTP auth probe (skipped when using Postmark/Resend API) ---"
    line smtp_auth_result(generic_smtp)
    line
    line "=== end mail:diag ==="
  end

  private
    def line(msg = "")
      @out.puts(msg)
    end

    def summarize_outbound_config(generic_smtp)
      if ::OutboundMailConfig.postmark_configured?
        extra = ::OutboundMailConfig.resend_fallback_configured? ? " + Resend API fallback (RESEND_API_KEY)" : ""
        "Postmark: HTTPS API (token set; not using smtp.postmarkapp.com)#{extra}"
      elsif generic_smtp
        "Generic SMTP (ActionMailer): #{generic_smtp[:address]}:#{generic_smtp[:port]} auth=#{generic_smtp[:authentication]}"
      else
        "Outbound: not configured (dev falls back to tmp/mail/)"
      end
    end

    def recent_tmp_mail_summary
      mail_dir = Rails.root.join("tmp/mail")
      return "tmp/mail: (none)" unless mail_dir.directory?

      eml = Dir.glob(mail_dir.join("*.eml").to_s).sort_by { |f| File.mtime(f) }.last(5)
      lines = [ "tmp/mail: #{eml.size} newest .eml shown (files here ⇒ not sent via SMTP)" ]
      eml.each { |f| lines << "  #{File.basename(f)} mtime=#{File.mtime(f)}" }
      lines.join("\n")
    end

    def followup_send_job_summary
      lines = [ "--- Recent FollowupSendJob ---" ]
      scope = SolidQueue::Job.where(class_name: "FollowupSendJob").order(created_at: :desc).limit(5)
      scope.each do |j|
        lines << "  id=#{j.id} finished=#{j.finished_at || "PENDING"} queue=#{j.queue_name}"
      end
      pending = SolidQueue::Job.where(class_name: "FollowupSendJob", finished_at: nil).count
      lines << "Unfinished FollowupSendJob: #{pending}"
      lines.join("\n")
    rescue StandardError => e
      "Solid Queue: #{e.message}"
    end

    def smtp_auth_result(generic_smtp)
      if ::OutboundMailConfig.postmark_configured?
        return "Skipped (Postmark uses HTTPS API; check Activity in Postmark dashboard)"
      end

      unless generic_smtp && generic_smtp[:user_name].present? && generic_smtp[:password].present?
        return "Skipped (no generic SMTP credentials; not used when Postmark is set)"
      end

      require "net/smtp"
      ok = nil
      Net::SMTP.start(
        generic_smtp[:address],
        generic_smtp[:port],
        ENV.fetch("SMTP_DOMAIN", "localhost"),
        generic_smtp[:user_name],
        generic_smtp[:password],
        generic_smtp[:authentication] || :plain
      ) { ok = "OK: authenticated to #{generic_smtp[:address]}" }
      ok
    rescue StandardError => e
      "FAILED: #{e.class}: #{e.message}"
    end
end
