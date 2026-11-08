require "rails_helper"

RSpec.describe ChartsHelper do
  describe "#chart_ticks" do
    it "rounds up to clean steps" do
      expect(helper.chart_ticks(160)).to eq([ 0, 50, 100, 150, 200 ])
      expect(helper.chart_ticks(7.62)).to eq([ 0, 2, 4, 6, 8 ])
      expect(helper.chart_ticks(40)).to eq([ 0, 10, 20, 30, 40 ])
    end

    it "has a usable scale for empty data" do
      expect(helper.chart_ticks(0)).to eq([ 0, 1 ])
    end
  end

  it "converts values to clamped percentages" do
    expect(helper.chart_pct(80, 160)).to eq("50.0%")
    expect(helper.chart_pct(200, 160)).to eq("100%")
    expect(helper.chart_pct(5, 0)).to eq("0%")
  end

  it "formats hours and money" do
    expect(helper.fmt_hours(160)).to eq("160h")
    expect(helper.fmt_hours(BigDecimal("7.6190"))).to eq("7.62h")
    expect(helper.fmt_hours(1234.5)).to eq("1,234.5h")
    expect(helper.fmt_money("PHP", 160_000)).to eq("PHP 160,000.00")
  end

  it "masks money until revealed" do
    html = helper.masked_money("PHP", 1000)
    expect(html).to include('data-reveal-target="item"', "PHP 1,000.00", "PHP ••••••")
  end

  it "maps holiday kinds to fixed series tones" do
    expect(TimeStats::HOLIDAY_KINDS.map { |k, _, _| helper.holiday_tone(k) }).to eq(%w[s1 s2 s3 s4 s5])
  end
end
