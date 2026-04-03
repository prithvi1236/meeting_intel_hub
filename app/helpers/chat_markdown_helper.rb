# frozen_string_literal: true

module ChatMarkdownHelper
  # Tags Commonmarker may emit for GFM-style chat replies; sanitized before display.
  CHAT_MARKDOWN_TAGS = %w[
    p br strong em b i u s del ins sup sub h1 h2 h3 h4 h5 h6
    ul ol li a code pre blockquote hr table thead tbody tr th td
    span img
  ].freeze

  CHAT_MARKDOWN_ATTRIBUTES = %w[
    href title rel target class colspan rowspan alt src width height
  ].freeze

  # Renders assistant chat content as HTML from Markdown (GFM-style). Output is sanitized.
  def assistant_chat_markdown_html(text)
    raw = text.to_s.dup
    raw.force_encoding(Encoding::UTF_8)
    unless raw.valid_encoding?
      raw = raw.encode(Encoding::UTF_8, Encoding::UTF_8, invalid: :replace, undef: :replace)
    end
    return "".html_safe if raw.blank?

    html = ::Commonmarker.to_html(
      raw,
      options: {
        extension: {
          strikethrough: true,
          table: true,
          autolink: true,
          tasklist: true,
          underline: true
        },
        render: {
          unsafe: true,
          hardbreaks: true,
          github_pre_lang: true
        }
      }
    )

    sanitize(
      html,
      tags: CHAT_MARKDOWN_TAGS,
      attributes: CHAT_MARKDOWN_ATTRIBUTES
    ).html_safe
  end
end
