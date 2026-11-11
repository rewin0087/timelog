require "rails_helper"

RSpec.describe TimelogAgent::Reply do
  it "splits the suggestions off the text" do
    reply = described_class.parse("All done.\n<suggestions>[\" What next? \", \"\", 3, \"Show today\", \"A\", \"B\"]</suggestions>")
    expect(reply.text).to eq("All done.")
    expect(reply.suggestions).to eq([ "What next?", "Show today", "A" ])
  end

  it "copes with missing or malformed suggestions and empty text" do
    expect(described_class.parse("Hi")).to have_attributes(text: "Hi", suggestions: [])
    expect(described_class.parse("Hi <suggestions>[oops</suggestions>")).to have_attributes(text: "Hi", suggestions: [])
    expect(described_class.parse(nil)).to have_attributes(text: "Done.", suggestions: [])
  end
end
