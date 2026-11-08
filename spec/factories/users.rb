FactoryBot.define do
  # A fully onboarded user: invoice details filled in and a lock code set.
  factory :user do
    sequence(:name) { |n| "Jamie Rivera #{n}" }
    sequence(:email_address) { |n| "user#{n}@example.com" }
    password { "password123" }
    lock_pin { "2580" }
    address { "1 Main St, Makati" }
    bill_to_name { "Acme Ltd" }
    bill_to_address { "1 Client Way\nLondon" }
    hourly_rate { 1000 }
    currency { "PHP" }
    bank_account_name { "Jamie Rivera" }
    bank_account_number { "0012345678" }
    bank_name { "BDO" }
    bank_swift { "BNORPHMM" }

    trait :invoice_ready # the default; kept so specs can say what they rely on

    # Invoices bill the fixed monthly target, skipping time logs (the default bills from time logs).
    trait :fixed_rate do
      invoice_hours_basis { "target" }
    end

    trait :without_lock do
      lock_pin { nil }
    end

    trait :without_invoice_details do
      address { nil }
      bill_to_name { nil }
      bill_to_address { nil }
      hourly_rate { nil }
      bank_account_name { nil }
      bank_account_number { nil }
      bank_name { nil }
      bank_swift { nil }
    end

    # Just signed up: nothing set beyond name, email and password.
    trait :new_signup do
      without_lock
      without_invoice_details
    end
  end
end
