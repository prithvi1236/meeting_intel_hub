# frozen_string_literal: true

module FollowupDraftsHelper
  def followup_email_resolution_pill_classes(draft)
    case draft.email_resolution_status
    when "matched"
      "border-[var(--mi-green)]/45 bg-[var(--mi-green)]/10 text-[var(--mi-green)]"
    when "conflict"
      "border-[var(--mi-red)]/35 bg-[var(--mi-red)]/[0.08] text-[var(--mi-red)]"
    else
      "border-[var(--mi-amber)]/40 bg-[var(--mi-amber)]/10 text-[var(--mi-amber)]"
    end
  end

  def followup_email_resolution_label(draft)
    t("followup.panel.email_status.#{draft.email_resolution_status}")
  end

  def followup_assignee_normalized_key(item)
    item.owner.to_s.downcase.strip
  end
end
