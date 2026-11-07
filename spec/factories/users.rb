FactoryBot.define do
  factory :user do
    sequence(:name) { |n| "Jamie Rivera #{n}" }
    sequence(:email_address) { |n| "user#{n}@example.com" }
    password { "password123" }
    lock_pin { "2580" }

    trait :without_lock do
      lock_pin { nil }
    end

    trait :invoice_ready do
      address { "1 Main St, Makati" }
      hourly_rate { 1000 }
      currency { "PHP" }
      bank_account_name { "Jamie Rivera" }
      bank_account_number { "0012345678" }
      bank_name { "BDO" }
      bank_swift { "BNORPHMM" }
    end
  end
end
