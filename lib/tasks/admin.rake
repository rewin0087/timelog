namespace :admin do
  desc "Create (or reset) a super admin: bin/rails admin:create EMAIL=you@example.com PASSWORD=secret123456 NAME='Your Name'"
  task create: :environment do
    email, password = ENV.fetch("EMAIL"), ENV.fetch("PASSWORD")
    admin = Administrator.find_or_initialize_by(email_address: email.strip.downcase)
    admin.assign_attributes(name: ENV.fetch("NAME", admin.name.presence || email.split("@").first), password: password, access_level: "all")
    admin.save!
    puts "Super admin #{admin.email_address} is ready. Sign in at /admin."
  end
end
