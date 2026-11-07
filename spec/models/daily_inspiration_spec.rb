require "rails_helper"

RSpec.describe DailyInspiration do
  let(:today) { Date.current }

  describe ".for" do
    it "returns the stored record for the day without calling the AI" do
      record = create(:daily_inspiration, day: today)
      expect(described_class.for(today)).to eq(record)
      expect(a_request(:post, FuelixHelpers::FUELIX_URL)).not_to have_been_made
    end

    it "uses the built-in fallback when FuelIX is not configured" do
      record = described_class.for(today)
      expect(record).to be_persisted
      expect(record).to be_fallback
      expect(record.questions.size).to eq(DailyInspiration::QUESTION_COUNT)
      expect(record.verse_reference).to be_present
    end

    it "generates from the AI when configured" do
      stub_fuelix(content: ai_payload)
      record = with_fuelix_key { described_class.for(today) }
      expect(record.source).to eq("ai")
      expect(record.verse_reference).to eq("Psalm 118:24")
      expect(record.questions.size).to eq(5)
      record.questions.each_with_index do |q, i|
        expect(q["choices"][q["answer_index"]]).to eq("Right #{i}") # answer still points at the right choice after shuffling
      end
    end

    it "falls back when the AI fails" do
      stub_fuelix(status: 500, body: "{}")
      record = with_fuelix_key { described_class.for(today) }
      expect(record).to be_fallback
    end

    it "falls back when the AI returns too few usable questions" do
      stub_fuelix(content: ai_payload(question_count: 2))
      expect(with_fuelix_key { described_class.for(today) }).to be_fallback
    end

    it "retries the AI for a fallback older than 30 minutes" do
      fallback = create(:daily_inspiration, day: today, source: "fallback", updated_at: 31.minutes.ago)
      stub_fuelix(content: ai_payload)
      record = with_fuelix_key { described_class.for(today) }
      expect(record.id).to eq(fallback.id)
      expect(record.reload.source).to eq("ai")
    end

    it "keeps a recent fallback without retrying" do
      fallback = create(:daily_inspiration, day: today, source: "fallback", updated_at: 10.minutes.ago)
      with_fuelix_key { expect(described_class.for(today)).to eq(fallback) }
      expect(a_request(:post, FuelixHelpers::FUELIX_URL)).not_to have_been_made
    end

    it "keeps the old fallback (and touches it) when the retry fails too" do
      fallback = create(:daily_inspiration, day: today, source: "fallback", updated_at: 31.minutes.ago)
      stub_fuelix(status: 500, body: "{}")
      with_fuelix_key { described_class.for(today) }
      expect(fallback.reload).to be_fallback
      expect(fallback.updated_at).to be_within(1.second).of(Time.current)
    end
  end

  describe ".normalize_question" do
    it "rejects questions without exactly 4 distinct choices or a valid answer" do
      base = { "question" => "Q?", "choices" => %w[a b c d], "answer_index" => 1 }
      expect(described_class.normalize_question(base)).to be_present
      expect(described_class.normalize_question(base.merge("choices" => %w[a b c]))).to be_nil
      expect(described_class.normalize_question(base.merge("choices" => %w[a a c d]))).to be_nil
      expect(described_class.normalize_question(base.merge("answer_index" => 4))).to be_nil
      expect(described_class.normalize_question(base.merge("answer_index" => "x"))).to be_nil
      expect(described_class.normalize_question(base.merge("question" => ""))).to be_nil
    end

    it "defaults the category" do
      q = described_class.normalize_question("question" => "Q?", "choices" => %w[a b c d], "answer_index" => 0)
      expect(q["category"]).to eq("Trivia")
    end
  end

  describe ".prompt" do
    it "asks to avoid recent verses and questions" do
      prompt = described_class.prompt(today, [ "John 3:16" ], [ "Old question?" ])
      expect(prompt).to include("John 3:16", "Old question?")
    end
  end

  describe "Fallback.attributes" do
    it "is deterministic per day and varies across days" do
      a = DailyInspiration::Fallback.attributes(today)
      expect(DailyInspiration::Fallback.attributes(today)).to eq(a)
      expect(DailyInspiration::Fallback.attributes(today + 1)[:verse_reference]).not_to eq(a[:verse_reference])
    end
  end
end
