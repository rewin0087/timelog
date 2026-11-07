require "rails_helper"

RSpec.describe Theme do
  it "has 13 skins with unique keys, including the default" do
    expect(Theme::ALL.size).to eq(13)
    expect(Theme::ALL.map(&:key).uniq.size).to eq(13)
    expect(Theme.valid?(Theme::DEFAULT)).to be(true)
  end

  it "resolves unknown keys to the default" do
    expect(Theme.resolve("ocean")).to eq("ocean")
    expect(Theme.resolve("nope")).to eq("violet")
    expect(Theme.resolve(nil)).to eq("violet")
  end
end
