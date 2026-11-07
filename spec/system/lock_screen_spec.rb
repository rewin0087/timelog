require "rails_helper"

RSpec.describe "Lock screen", :js do
  let(:user) { create(:user) }

  before { sign_in_ui(user) }

  def press(code) = code.each_char { |d| find("button.key", exact_text: d).click }

  it "locks from the sidebar and unlocks with the keypad" do
    find("button[aria-label='Lock screen']").click
    expect(page).to have_content("Screen locked")
    expect(page).to have_no_css("aside.sidebar")

    press("2580")
    expect(page).to have_css(".pin-dots i.on", count: 4)
    find("button[aria-label='Unlock']").click
    expect(page).to have_content("Today's todo")
    expect(page).to have_css("aside.sidebar")
  end

  it "returns to the blocked page after unlocking" do
    visit time_entries_path
    user.sessions.last.lock!
    visit invoices_path
    expect(page).to have_content("Screen locked")
    press("2580")
    find("button[aria-label='Unlock']").click
    expect(page).to have_css("h2", text: "Invoices")
  end

  it "lays out the keypad as a 3-column grid of full-size buttons" do
    find("button[aria-label='Lock screen']").click
    expect(page).to have_css(".keypad button.key", count: 12)
    sizes = page.evaluate_script(<<~JS)
      [...document.querySelectorAll(".keypad .key")].map(k => { const r = k.getBoundingClientRect(); return [Math.round(r.width), Math.round(r.height), Math.round(r.left)] })
    JS
    expect(sizes.map { |w, h, _| [ w, h ] }).to all(satisfy { |w, h| w >= 60 && h >= 60 })
    expect(sizes.map(&:last).uniq.size).to eq(3)
  end

  it "erases digits and rejects a wrong code" do
    find("button[aria-label='Lock screen']").click
    press("1119")
    find("button[aria-label='Delete']").click
    expect(page).to have_css(".pin-dots i.on", count: 3)
    press("1")
    find("button[aria-label='Unlock']").click
    expect(page).to have_content("Wrong code. 4 attempts left before you're signed out.")
  end

  it "locks with Ctrl+Shift+L" do
    find("body").send_keys([ :control, :shift, "l" ])
    expect(page).to have_content("Screen locked")
  end

  it "can switch to typing the code, and remembers the choice" do
    find("button[aria-label='Lock screen']").click
    click_on "Type code instead"
    expect(page).to have_button("Use keypad instead")
    find("#pin").fill_in(with: "2580")
    find("#pin").send_keys(:enter)
    expect(page).to have_content("Today's todo")

    find("button[aria-label='Lock screen']").click
    expect(page).to have_button("Use keypad instead")
  end

  it "keeps pages behind the lock" do
    find("button[aria-label='Lock screen']").click
    expect(page).to have_content("Screen locked")
    visit invoices_path
    expect(page).to have_content("Screen locked")
  end

  it "signs out after 5 wrong codes" do
    find("button[aria-label='Lock screen']").click
    4.times do |i|
      press("1119")
      find("button[aria-label='Unlock']").click
      expect(page).to have_content("#{4 - i} attempt")
    end
    press("1119")
    find("button[aria-label='Unlock']").click
    expect(page).to have_content("Too many wrong codes")
    expect(page).to have_button("Sign in")
  end
end
