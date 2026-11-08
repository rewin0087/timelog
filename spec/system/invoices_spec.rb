require "rails_helper"

RSpec.describe "Invoices" do
  let(:user) { create(:user, :invoice_ready, hourly_rate: 1000) }

  it "generates a month invoice" do
    sign_in_ui(user)
    click_on "Invoices"
    select "October 2026", from: "period"
    click_on "Generate invoice"
    expect(page).to have_content("Invoice INV-001 for October 2026 generated.")
    expect(page).to have_content("Billed vs logged hours")
  end

  it "generates a custom-range invoice with extra items and tax", :js do
    sign_in_ui(user)
    click_on "Invoices"
    expect(page).to have_no_field("From")
    select "Custom dates…", from: "period"
    fill_in "From", with: "2026-11-02"
    fill_in "To", with: "2026-11-06"
    fill_in "Due", with: "2026-11-20"
    fill_in "Tax rate (%)", with: "10"

    click_on "+ Add item"
    within(all(".item-row").last) do
      fill_in "Description", with: "Equipment allowance"
      fill_in "Rate", with: "2500"
      fill_in "Qty", with: "2"
      expect(page).to have_content("PHP 5,000.00")
    end
    click_on "+ Add item"
    within(all(".item-row").last) { find("button[aria-label='Remove item']").click }
    expect(page).to have_css(".item-row", count: 1)

    click_on "Generate invoice"
    expect(page).to have_content("Invoice INV-001 for 2–6 November 2026 generated with 1 extra item and 10% tax.")
    within("table.rtable") { expect(page).to have_content("(custom)").and have_content("+ 1 extra item · 10% tax") }
    expect(user.invoices.last.amount).to eq(47_410) # (5 of 21 weekdays x 160h x 1,000 = 38,100 + 5,000) + 10%
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
      within("table.rtable tbody tr", text: "INV-001") { click_on "Preview" }
      within("dialog.pdf-modal[open]") do
        expect(page).to have_content("Invoice INV-001")
        expect(find("iframe", visible: :all)[:src]).to include("inline=1")
      end
    end

    it "previews a draft invoice with the picked design and colour before generating" do
      sign_in_ui(user)
      click_on "Invoices"
      select "Modern: full-width colour header, striped rows", from: "Design"
      find(".pdf-swatch[title='Teal']").click
      expect(page).to have_css(".pdf-swatch.active[title='Teal']")
      click_on "Preview PDF"
      within("dialog.pdf-modal[open]") do
        expect(page).to have_content("Invoice preview (not saved yet)")
        src = find("iframe", visible: :all)[:src]
        expect(src).to include("/invoices/preview", "design=modern", "color=%230f766e", "inline=1")
        expect(src).not_to include("authenticity_token")
      end
      expect(user.invoices.count).to eq(1)
    end
  end
end
