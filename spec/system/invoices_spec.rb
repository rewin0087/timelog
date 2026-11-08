require "rails_helper"

RSpec.describe "Invoices" do
  let(:user) { create(:user, :invoice_ready, hourly_rate: 1000) }

  it "generates month and custom-range invoices" do
    sign_in_ui(user)
    click_on "Invoices"
    select "October 2026", from: "period"
    click_on "Generate invoice"
    expect(page).to have_content("Invoice INV-001 for October 2026 generated.")

    fill_in "From", with: "2026-11-02"
    fill_in "To", with: "2026-11-06"
    fill_in "Due", with: "2026-11-20"
    click_on "Generate custom invoice"
    expect(page).to have_content("Invoice INV-002 for 2–6 November 2026 generated.")
    within("table.rtable") { expect(page).to have_content("INV-002").and have_content("(custom)") }
    expect(page).to have_content("Billed vs logged hours")
  end

  context "with JavaScript", :js do
    before { Invoice.generate_for(user, Date.new(2026, 10, 1)) }

    it "keeps amounts hidden until revealed, one at a time or all at once" do
      sign_in_ui(user)
      click_on "Invoices"
      row = find("table.rtable tbody tr", text: "INV-001")
      expect(row).to have_content("PHP ••••••")
      expect(row).to have_no_content("PHP 160,000.00")
      expect(page).to have_no_content("PHP 160,000.00")

      row.find("button[aria-label='Show amount']").click
      expect(row).to have_content("PHP 160,000.00")
      row.find("button[aria-label='Hide amount']").click
      expect(row).to have_no_content("PHP 160,000.00")

      first("button[aria-label='Show all amounts']").click
      expect(find(".stat", text: /billed in 2026/i)).to have_content("PHP 160,000.00")
      expect(row).to have_content("PHP 160,000.00")
      expect(page).to have_css("button.revealed[aria-label='Hide all amounts']", count: 2)

      first("button[aria-label='Hide all amounts']").click
      expect(page).to have_no_content("PHP 160,000.00")
    end

    it "opens the invoice PDF preview" do
      sign_in_ui(user)
      click_on "Invoices"
      click_on "Preview"
      within("dialog.pdf-modal[open]") do
        expect(page).to have_content("Invoice INV-001")
        expect(find("iframe", visible: :all)[:src]).to include("inline=1")
      end
    end
  end
end
