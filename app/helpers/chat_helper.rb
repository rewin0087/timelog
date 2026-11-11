# Renders the assistant's light Markdown (paragraphs, "-"/"1." lists, tables, **bold**, *italic*, `code`,
# and # headings) as HTML. Everything is escaped first, so only these few tags can come out.
module ChatHelper
  LIST_ITEM = /\A\s*([-*•]|\d+[.)])\s+/
  # Starters for a new chat, from the user's own data (see AssistantSuggestions).
  def starter_suggestions = AssistantSuggestions.new(Current.user).to_a

  def chat_markdown(text)
    blocks = text.to_s.strip.split(/\n{2,}/)
    safe_join(blocks.flat_map { |block| markdown_block(block) })
  end

  private

  def markdown_block(block)
    lines = block.lines.map(&:chomp)
    if lines.all? { |l| l.match?(/\A\s*\|.*\|\s*\z/) } && lines.size >= 2
      markdown_table(lines)
    elsif lines.all? { |l| l.match?(/\A\s*[-*•]\s+/) }
      tag.ul(safe_join(lines.map { |l| tag.li(markdown_inline(l.sub(/\A\s*[-*•]\s+/, ""))) }))
    elsif lines.all? { |l| l.match?(/\A\s*\d+[.)]\s+/) }
      tag.ol(safe_join(lines.map { |l| tag.li(markdown_inline(l.sub(/\A\s*\d+[.)]\s+/, ""))) }))
    elsif lines.size > 1 && !lines.first.match?(LIST_ITEM) && lines.drop(1).all? { |l| l.match?(LIST_ITEM) }
      [ markdown_block(lines.first), markdown_block(lines.drop(1).join("\n")) ].flatten # "Intro:\n- a\n- b"
    elsif (heading = lines.first[/\A#+\s+(.*)/, 1]) && lines.size == 1
      tag.p(tag.strong(markdown_inline(heading)), class: "chat-heading")
    else
      tag.p(safe_join(lines.map { |l| markdown_inline(l) }, tag.br))
    end
  end

  def markdown_table(lines)
    rows = lines.reject { |l| l.match?(/\A\s*\|[\s:|-]+\|\s*\z/) }.map { |l| l.strip.delete_prefix("|").delete_suffix("|").split("|").map(&:strip) }
    head, *body = rows
    tag.div(class: "chat-table-wrap") do
      tag.table(class: "chat-table") do
        tag.thead(tag.tr(safe_join(head.map { |c| tag.th(markdown_inline(c)) }))) +
          tag.tbody(safe_join(body.map { |r| tag.tr(safe_join(r.map { |c| tag.td(markdown_inline(c)) })) }))
      end
    end
  end

  def markdown_inline(text)
    html = ERB::Util.html_escape(text).to_str
    html = html.gsub(/`([^`]+)`/) { "<code>#{$1}</code>" }
    html = html.gsub(/\*\*(.+?)\*\*/) { "<strong>#{$1}</strong>" }
    html = html.gsub(/(?<![*\w])\*(?!\s)(.+?)(?<!\s)\*(?![*\w])/) { "<em>#{$1}</em>" }
    html.html_safe # rubocop:disable Rails/OutputSafety -- built from escaped text plus fixed tags
  end
end
