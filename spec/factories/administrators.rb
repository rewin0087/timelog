FactoryBot.define do
  factory :administrator do
    sequence(:name) { |n| "Admin #{n}" }
    sequence(:email_address) { |n| "admin#{n}@example.com" }
    password { "admin-password" }
    access_level { "view" }

    trait(:super) { access_level { "all" } }
    trait(:creator) { access_level { "create" } }
    trait(:editor) { access_level { "edit" } }
  end
end
