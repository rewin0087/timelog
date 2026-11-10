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

  it "uses built-in serif and monospaced fonts for the elegant and typewriter designs" do
    expect(PdfStyle::DESIGNS.keys.map { |d| described_class.new(:report, design: d).font }.uniq).to contain_exactly("Helvetica", "Times-Roman", "Courier")
    expect(described_class.new(:report, design: "typewriter").font).to eq("Courier")
  end

  it "derives a deep shade for white text and a gradient partner with the same text colour" do
    [ "FBE3D6", "AAAAAA", "4F46E5", "FFF1B8", "0F766E", "D3F5E4" ].each do |hex|
      style = described_class.new(:report, color: hex)
      expect(style.text_on(style.deep)).to eq("FFFFFF"), hex
      expect(style.partner).to match(/\A\h{6}\z/)
      expect(style.text_on(style.partner)).to eq(style.text_color), hex
    end
    expect(described_class.new(:report, color: "4F46E5").partner).not_to eq("4F46E5")
  end
end
