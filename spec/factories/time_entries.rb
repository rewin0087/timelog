FactoryBot.define do
  factory :time_entry do
    user
    log_date { Date.current }
    sequence(:todo) { |n| "Task #{n}" }
  end
end
