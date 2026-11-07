FactoryBot.define do
  factory :session do
    user
    last_active_at { Time.current }
  end
end
