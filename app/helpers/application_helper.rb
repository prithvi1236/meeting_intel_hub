module ApplicationHelper
  include FollowupDraftsHelper
  include ChatMarkdownHelper

  # Shared Tailwind fragments for meeting peek / panels (keeps views readable).
  MI_SURFACE_INTERACTIVE_BASE =
    "rounded-lg border border-[var(--mi-border)] bg-[var(--mi-surface)] " \
    "transition-colors hover:border-[var(--mi-teal)]/40 hover:bg-[var(--mi-teal)]/[0.06] " \
    "focus:outline-none focus-visible:ring-2 focus-visible:ring-[var(--mi-teal)]/40 " \
    "focus-visible:ring-offset-2 focus-visible:ring-offset-[var(--mi-surface)]"

  def mi_btn_export_class
    "inline-flex items-center justify-center #{MI_SURFACE_INTERACTIVE_BASE} " \
      "px-3 py-1.5 text-xs font-mono-mi text-[var(--mi-text)]"
  end

  def mi_icon_btn_edit_class
    "inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-lg border " \
      "border-[var(--mi-teal)]/45 bg-[var(--mi-teal)]/[0.1] text-[var(--mi-teal)] " \
      "transition-colors hover:border-[var(--mi-teal)]/70 hover:bg-[var(--mi-teal)]/[0.18] " \
      "focus:outline-none focus-visible:ring-2 focus-visible:ring-[var(--mi-teal)]/50 " \
      "focus-visible:ring-offset-2 focus-visible:ring-offset-[var(--mi-surface)]"
  end

  def mi_icon_btn_danger_class
    "inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-lg border " \
      "border-[var(--mi-red)]/45 bg-[var(--mi-red)]/[0.06] text-[var(--mi-red)] " \
      "transition-colors hover:bg-[var(--mi-red)]/[0.14] focus:outline-none " \
      "focus-visible:ring-2 focus-visible:ring-[var(--mi-red)]/35 " \
      "focus-visible:ring-offset-2 focus-visible:ring-offset-[var(--mi-surface)]"
  end

  def mi_panel_class
    "rounded-xl border border-[var(--mi-border)] bg-[var(--mi-surface)] shadow-sm"
  end

  def mi_panel_header_class
    "border-b border-[var(--mi-border)] px-3 py-2.5 text-[11px] font-mono-mi font-medium " \
      "uppercase tracking-[0.14em] text-[var(--mi-text)]/85"
  end

  def mi_peek_scroll_body_class
    "min-h-0 flex-1 overflow-y-auto p-3.5 [scrollbar-width:thin] " \
      "[scrollbar-color:var(--mi-border)_transparent]"
  end

  def mi_peek_extracted_toolbar_class
    "flex shrink-0 flex-wrap items-center justify-between gap-2 border-b " \
      "border-[var(--mi-border)] bg-[var(--mi-surface)]/60 px-3 py-2.5"
  end

  def mi_panel_heading_muted_class
    "m-0 text-[11px] font-mono-mi font-medium uppercase tracking-[0.14em] text-[var(--mi-text)]/85"
  end

  def mi_chat_clear_toolbar_icon_btn_class
    "inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-lg border " \
      "border-[var(--mi-border)] bg-[var(--mi-surface)] text-[var(--mi-text)] " \
      "transition-colors hover:border-[var(--mi-red)]/35 hover:bg-[var(--mi-red)]/[0.06] " \
      "focus:outline-none focus-visible:ring-2 focus-visible:ring-[var(--mi-teal)]/40 " \
      "focus-visible:ring-offset-2 focus-visible:ring-offset-[var(--mi-surface)]"
  end

  def mi_chat_send_btn_class
    "inline-flex h-[2.625rem] min-w-[2.75rem] shrink-0 items-center justify-center self-end " \
      "rounded-[8px] bg-[var(--mi-teal)] px-3 text-[#0f0f0f] transition-colors " \
      "hover:bg-[var(--mi-teal)]/90 focus:outline-none focus-visible:ring-2 " \
      "focus-visible:ring-[var(--mi-teal)]/50 focus-visible:ring-offset-2 " \
      "focus-visible:ring-offset-[var(--mi-bg)]"
  end

  def mi_meeting_status_pill_class(status)
    case status.to_s
    when "completed"
      "border-[var(--mi-green)]/30 bg-[var(--mi-green)]/[0.12] text-[var(--mi-green)]"
    when "failed"
      "border-[var(--mi-red)]/35 bg-[var(--mi-red)]/[0.1] text-[var(--mi-red)]"
    when "processing", "pending"
      "border-[var(--mi-teal)]/30 bg-[var(--mi-teal)]/[0.1] text-[var(--mi-teal)]"
    else
      "border-[var(--mi-border)] bg-[var(--mi-bg)]/50 text-[var(--mi-text-secondary)]"
    end
  end

  def sentiment_color(score)
    return "text-[var(--mi-text-secondary)]" if score.nil?

    if score >= 0.35
      "text-[var(--mi-green)]"
    elsif score <= -0.35
      "text-[var(--mi-red)]"
    else
      "text-[var(--mi-amber)]"
    end
  end

  def sentiment_delta_prefix(value)
    return "" if value.nil? || value.zero?

    value.positive? ? "+" : ""
  end

  def sentiment_bar_class(label)
    case label.to_s
    when "consensus" then "bg-[var(--mi-green)]"
    when "discussion" then "bg-[var(--mi-teal)]"
    when "tension" then "bg-[var(--mi-amber)]"
    when "conflict" then "bg-[var(--mi-red)]"
    else "bg-[var(--mi-border)]"
    end
  end
end
