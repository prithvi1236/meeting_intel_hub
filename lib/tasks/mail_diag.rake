# frozen_string_literal: true

namespace :mail do
  desc "Mail/SMTP summary, Postmark auth probe, follow-up drafts, Solid Queue send jobs (no secrets)"
  task diag: :environment do
    MailDiagnostics.run
  end
end
