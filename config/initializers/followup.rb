# frozen_string_literal: true

# Outbound delivery uses Action Mailer (see config/mailer_smtp_config.rb).
# With Postmark, set POSTMARK_API_TOKEN. Each user’s address used as From must be verified
# (Sender Signatures), or use a fallback: FOLLOWUP_FROM_EMAIL when sender_email is blank (legacy rows).
module FollowupConfig
  DEFAULT_CHANNEL = ENV.fetch("FOLLOWUP_DEFAULT_CHANNEL", "email").freeze
  SEND_DELAY_MINUTES = ENV.fetch("FOLLOWUP_SEND_DELAY_MINUTES", "0").to_i
  AI_MAX_TOKENS = ENV.fetch("FOLLOWUP_AI_MAX_TOKENS", "600").to_i
  FROM_EMAIL = ENV.fetch("FOLLOWUP_FROM_EMAIL", "noreply@example.com").freeze
  FROM_NAME = ENV.fetch("FOLLOWUP_FROM_NAME", "Meeting Intelligence Hub").freeze
end
