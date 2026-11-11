require "rails_helper"

RSpec.describe ChatHelper do
  it "renders lists, tables and inline styles" do
    html = helper.chat_markdown("Here you go:\n- **7.62h** on `Mon`\n- *one* more\n\n| Date | Todo | Hours |\n|---|---|---|\n| Mon, 10 Nov | Fix bug | 7.62 |")
    expect(html).to include("<p>Here you go:</p>", "<li><strong>7.62h</strong> on <code>Mon</code></li>", "<em>one</em>")
    expect(html).to include("<th>Date</th>", "<td>Fix bug</td>")
  end

  it "escapes HTML from the model" do
    expect(helper.chat_markdown("<script>alert(1)</script> **hi**")).to include("&lt;script&gt;", "<strong>hi</strong>")
  end

  it "renders a bold heading line followed by a list" do
    html = helper.chat_markdown("**Invoice INV-001**\n- Total: **PHP 7,620.00**\n- Due: 5 Dec")
    expect(html).to include("<p><strong>Invoice INV-001</strong></p><ul><li>Total: <strong>PHP 7,620.00</strong></li>")
  end
end
