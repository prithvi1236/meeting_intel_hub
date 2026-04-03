# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#assistant_chat_markdown_html" do
    it "renders bold and italic" do
      html = helper.assistant_chat_markdown_html("**bold** and *italic*")
      expect(html).to include("<strong>bold</strong>")
      expect(html).to include("<em>italic</em>")
    end

    it "allows underline from HTML when unsafe content is sanitized" do
      raw = +"Hello <u>there</u>"
      raw.force_encoding(Encoding::UTF_8)
      html = helper.assistant_chat_markdown_html(raw)
      expect(html).to include("<u>there</u>")
    end

    it "does not emit raw script tags" do
      html = helper.assistant_chat_markdown_html('Hi <script>alert(1)</script>')
      expect(html).not_to match(/<script/i)
    end
  end
end
