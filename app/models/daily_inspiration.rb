# One Bible verse and a set of multiple-choice trivia questions per day, shared by all users.
# Generated with FuelIX on first request of the day; falls back to a built-in set if the AI is
# unavailable, and retries the AI after RETRY_FALLBACK_AFTER.
class DailyInspiration < ApplicationRecord
  QUESTION_COUNT = 5
  RETRY_FALLBACK_AFTER = 30.minutes

  validates :day, presence: true, uniqueness: true
  validates :verse_text, :verse_reference, presence: true

  def self.for(day = Date.current)
    record = find_by(day:)
    return record if record && !(record.fallback? && record.updated_at < RETRY_FALLBACK_AFTER.ago && FuelixClient.configured?)

    generate!(day, existing: record)
  end

  def self.generate!(day, existing: nil)
    attrs = begin
      ai_attributes(day)
    rescue FuelixClient::Error, KeyError, TypeError, ArgumentError, NoMethodError => e
      Rails.logger.warn("[DailyInspiration] AI generation failed, using fallback: #{e.message}")
      return existing.tap(&:touch) if existing # keep today's fallback; retry after RETRY_FALLBACK_AFTER
      Fallback.attributes(day)
    end

    record = existing || new(day:)
    record.update!(attrs)
    record
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    find_by!(day:) # another request generated it first
  end

  def self.ai_attributes(day)
    recent = where(day: (day - 30)...day).order(day: :desc)
    avoid_verses = recent.pluck(:verse_reference).uniq
    avoid_questions = recent.limit(3).flat_map { |r| r.questions.map { |q| q["question"] } }

    data = FuelixClient.new.complete_json(prompt(day, avoid_verses, avoid_questions), temperature: 1.0, max_tokens: 2500)
    verse = data.fetch("verse")
    questions = Array(data.fetch("questions")).filter_map { |q| normalize_question(q) }.first(QUESTION_COUNT)
    raise ArgumentError, "only #{questions.size} usable questions" if questions.size < 3

    {
      verse_text: verse.fetch("text").to_s.strip,
      verse_reference: verse.fetch("reference").to_s.strip,
      verse_reflection: verse["reflection"].to_s.strip.presence,
      questions:,
      source: "ai"
    }
  end

  # Validates the AI's question and shuffles the choices (models favour putting the answer in the same slot).
  def self.normalize_question(q)
    choices = Array(q["choices"]).map { |c| c.to_s.strip }.reject(&:blank?)
    answer = Integer(q["answer_index"])
    return unless q["question"].present? && choices.size == 4 && choices.uniq.size == 4 && answer.between?(0, 3)

    correct = choices[answer]
    shuffled = choices.shuffle
    {
      "category" => q["category"].to_s.strip.presence || "Trivia",
      "question" => q["question"].to_s.strip,
      "choices" => shuffled,
      "answer_index" => shuffled.index(correct),
      "explanation" => q["explanation"].to_s.strip
    }
  rescue ArgumentError, TypeError
    nil
  end

  def self.prompt(day, avoid_verses, avoid_questions)
    <<~PROMPT
      Today is #{day.strftime("%A, %d %B %Y")}. Create content for a "start your workday" panel in a time-tracking app.

      1. One Bible verse that encourages and inspires someone at the start of their workday (diligence, peace, hope, strength, gratitude, rest, kindness, etc.). Quote it accurately from the World English Bible (WEB). Add a one-sentence, warm reflection on how it applies to today's work.
      #{"Do not use any of these references: #{avoid_verses.join("; ")}." if avoid_verses.any?}

      2. #{QUESTION_COUNT} multiple-choice trivia questions about surprising but verifiable random facts. Use a different category for each (e.g. science, history, geography, animals, space, food, language, art, sport, technology, the human body). Each has exactly 4 distinct, plausible choices and exactly one correct answer. Keep questions under 160 characters and choices under 60. Add a one-sentence explanation with the interesting fact. Only include well-established facts you are certain of, and double-check that none of the three wrong choices could also be considered correct.
      #{"Do not repeat these recent questions: #{avoid_questions.join(" | ")}" if avoid_questions.any?}

      Return ONLY a minified JSON object, no markdown, in this exact shape:
      {"verse":{"text":"...","reference":"Book Chapter:Verse","reflection":"..."},"questions":[{"category":"...","question":"...","choices":["...","...","...","..."],"answer_index":0,"explanation":"..."}]}
    PROMPT
  end

  def fallback? = source == "fallback"

  # Built-in content for when FuelIX is not configured or not reachable.
  module Fallback
    VERSES = [
      [ "Whatever you do, work heartily, as for the Lord, and not for men.", "Colossians 3:23", "Do today's work with care, whoever sees it." ],
      [ "Commit your deeds to Yahweh, and your plans shall succeed.", "Proverbs 16:3", "Hand over the plan, then do the next small step." ],
      [ "This is the day that Yahweh has made. We will rejoice and be glad in it!", "Psalm 118:24", "Today is a gift; meet it with gladness." ],
      [ "I can do all things through Christ, who strengthens me.", "Philippians 4:13", "The hard task on your list is not too hard today." ],
      [ "Let's not be weary in doing good, for we will reap in due season, if we don't give up.", "Galatians 6:9", "Steady work adds up, even when progress feels slow." ],
      [ "Come to me, all you who labor and are heavily burdened, and I will give you rest.", "Matthew 11:28", "Work hard, and remember to rest." ],
      [ "Don't be anxious for anything; but in everything, by prayer and petition with thanksgiving, let your requests be made known to God.", "Philippians 4:6", "Trade worry for a thankful, focused start." ]
    ].freeze

    QUESTIONS = [
      [ "Space", "Which planet has the shortest day in our solar system?", [ "Jupiter", "Mercury", "Earth", "Neptune" ], 0, "Jupiter spins once roughly every 10 hours." ],
      [ "Animals", "How many hearts does an octopus have?", [ "One", "Two", "Three", "Four" ], 2, "Two pump blood to the gills and one to the rest of the body." ],
      [ "Food", "Which food never spoils if stored properly?", [ "Rice", "Honey", "Peanut butter", "Cheese" ], 1, "Edible honey has been found in ancient Egyptian tombs." ],
      [ "Geography", "What is the smallest country in the world by area?", [ "Monaco", "San Marino", "Vatican City", "Nauru" ], 2, "Vatican City covers about 0.49 square kilometres." ],
      [ "Human body", "Which is the largest organ of the human body?", [ "Liver", "Brain", "Lungs", "Skin" ], 3, "Skin makes up around 15% of body weight." ],
      [ "History", "Which ancient wonder stood in Alexandria?", [ "The Colossus", "The Lighthouse", "The Hanging Gardens", "The Mausoleum" ], 1, "The Pharos lighthouse guided ships for centuries." ],
      [ "Science", "What is the chemical symbol for gold?", [ "Go", "Gd", "Au", "Ag" ], 2, "Au comes from the Latin word 'aurum'." ],
      [ "Language", "Which language has the most native speakers?", [ "English", "Spanish", "Hindi", "Mandarin Chinese" ], 3, "Mandarin has over 900 million native speakers." ],
      [ "Technology", "What does 'HTTP' stand for?", [ "HyperText Transfer Protocol", "High Transfer Text Process", "Hyperlink Text Transport Protocol", "Host Transfer Text Protocol" ], 0, "HTTP was created by Tim Berners-Lee around 1990." ],
      [ "Animals", "What is a group of flamingos called?", [ "A parade", "A flamboyance", "A blush", "A colony" ], 1, "Yes, really: a flamboyance of flamingos." ]
    ].freeze

    def self.attributes(day)
      text, reference, reflection = VERSES[day.jd % VERSES.size]
      start = day.jd % QUESTIONS.size
      questions = QUESTION_COUNT.times.map do |i|
        category, question, choices, answer, explanation = QUESTIONS[(start + i) % QUESTIONS.size]
        { "category" => category, "question" => question, "choices" => choices, "answer_index" => answer, "explanation" => explanation }
      end
      { verse_text: text, verse_reference: reference, verse_reflection: reflection, questions:, source: "fallback" }
    end
  end
end
