FactoryBot.define do
  factory :daily_inspiration do
    day { Date.current }
    verse_text { "Whatever you do, work heartily." }
    verse_reference { "Colossians 3:23" }
    verse_reflection { "Do today's work with care." }
    source { "ai" }
    questions do
      [ { "category" => "Science", "question" => "What is the chemical symbol for gold?",
          "choices" => %w[Go Gd Au Ag], "answer_index" => 2, "explanation" => "From the Latin aurum." },
        { "category" => "Animals", "question" => "How many hearts does an octopus have?",
          "choices" => %w[One Two Three Four], "answer_index" => 2, "explanation" => "Three hearts." } ]
    end
  end
end
