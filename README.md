# Timelog

Rails 8 + PostgreSQL app for daily timelog tracking with PDF export (Prawn).

    bundle install
    bin/rails db:create db:migrate
    bin/rails s     # http://localhost:3000

- **Dashboard** (`/`): quick-add today's todo + hours (dated automatically); week view, or `?view=month` for the monthly report.
- **Manage logs** (`/time_entries`): create / edit / delete any entry on any date.
- **Export** (`/reports`): PDF of the current month (default), previous month, last N days/weeks, or a custom date range.
