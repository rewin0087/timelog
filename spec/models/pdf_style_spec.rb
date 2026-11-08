require "rails_helper"

RSpec.describe PdfStyle do
  it "defaults to the original look" do
    expect(described_class.new(:report)).to have_attributes(design: "classic", color: "FBE3D6", text_color: "000000")
    expect(described_class.new(:invoice)).to have_attributes(design: "classic", color: "AAAAAA")
  end

  it "takes the first valid design and colour" do
    style = described_class.new(:invoice, design: [ "fancy", nil, "modern" ], color: [ "", "#4f46e5", "FFFFFF" ])
    expect(style).to have_attributes(design: "modern", color: "4F46E5", text_color: "FFFFFF")
  end

  it "picks readable text and derives tint and strong shades" do
    expect(described_class.new(:report, color: "1F2937").text_color).to eq("FFFFFF")
    pale = described_class.new(:report)
    expect(pale.strong).not_to eq(pale.color)
    expect(pale.tint).to match(/\A\h{6}\z/)
  end

  it "reads request params before the user's defaults" do
    user = build(:user, report_design: "minimal", report_color: "0F766E")
    expect(described_class.from(:report, {}, user)).to have_attributes(design: "minimal", color: "0F766E")
    expect(described_class.from(:report, { design: "modern", color: "#B91C1C" }, user)).to have_attributes(design: "modern", color: "B91C1C")
  end
end
