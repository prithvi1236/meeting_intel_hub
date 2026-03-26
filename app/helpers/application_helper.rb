module ApplicationHelper
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
