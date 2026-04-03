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
    smtp = MailerSmtpConfig.build_smtp_settings
    line summarize_smtp_config(smtp)
    line
    line "--- Action Mailer (RAILS_ENV=#{Rails.env}) ---"
    line "delivery_method: #{ActionMailer::Base.delivery_method}"
    line recent_tmp_mail_summary
    line
    line "--- Active Job ---"
    line "Adapter: #{ActiveJob::Base.queue_adapter.class.name}"
    line
    line "--- FollowupDraft ---"
    line FollowupDraft.group(:status).count.inspect
    confirmed = FollowupDraft.where(status: :confirmed)
    line "Confirmed (queued in UI): #{confirmed.count}"
    confirmed.limit(5).find_each { |d| line "  id=#{d.id} updated_at=#{d.updated_at}" }
    line
    line followup_send_job_summary
    line
    line "--- SMTP auth (no email sent) ---"
    line smtp_auth_result(smtp)
    line
    line "=== end mail:diag ==="
  end

  private
    def line(msg = "")
      @out.puts(msg)
    end

    def summarize_smtp_config(smtp)
      if smtp
        parts = [ "SMTP: #{smtp[:address]}:#{smtp[:port]} auth=#{smtp[:authentication]}" ]
        if MailerSmtpConfig.postmark_api_token.present?
          parts << "Postmark token: set"
        elsif smtp[:address].to_s.include?("postmark")
          parts << "Postmark host but no token in env"
        end
        parts.join(" — ")
      else
        "SMTP: not configured (dev falls back to tmp/mail/)"
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

    def smtp_auth_result(smtp)
      unless smtp && smtp[:user_name].present? && smtp[:password].present?
        return "Skipped (no SMTP credentials)"
      end

      require "net/smtp"
      ok = nil
      Net::SMTP.start(
        smtp[:address],
        smtp[:port],
        ENV.fetch("SMTP_DOMAIN", "localhost"),
        smtp[:user_name],
        smtp[:password],
        smtp[:authentication] || :plain
      ) { ok = "OK: authenticated to #{smtp[:address]}" }
      ok
    rescue StandardError => e
      "FAILED: #{e.class}: #{e.message}"
    end
end
