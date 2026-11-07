# Timelog

A small Rails 8 app for contractors to log daily work, export monthly timelog PDFs, and generate invoices. Each user has their own account, entries, and invoices.

## Stack

- Ruby 3.4.9, Rails 8.1
- PostgreSQL
- Hotwire (Turbo + Stimulus), import maps, Propshaft
- [Prawn](https://github.com/prawnpdf/prawn) + prawn-table for PDF generation
- Rails' built-in authentication (`has_secure_password`, cookie-backed sessions)

## Getting started

Prerequisites: Ruby 3.4.9 and a running PostgreSQL server (the dev database is `timelog_development`, using your OS user as the role by default; see `config/database.yml`).

    bundle install
    bin/rails db:create db:migrate
    bin/rails s     # http://localhost:3000

Or run `bin/setup` to install gems, prepare the database, and start the server in one step.

Open the app, go to **Sign up** (`/signup`), and create an account. You'll then be asked to choose a lock code (see [Lock screen](#lock-screen-lock)). Everything after that requires being signed in and unlocked.

## Features

### Layout, skins, and mobile

- Navigation lives in a left sidebar. Page changes animate with the View Transitions API: the new page slides in from the window edge (from the right going forward, from the left going back).
- **Skins:** 13 colour themes, picked from the swatches in the sidebar: Violet (default), Ocean, Sunset, Forest, Candy, Midnight, Rainbow, Lemonade, Ruby, Slate, Mocha, Neon, and Aurora. Midnight, Neon, and Aurora are dark. The choice is saved in the Rails session, so it resets to Violet after signing out. Skins are listed in `app/models/theme.rb` and defined as CSS custom properties in `app/assets/stylesheets/application.css`.
- **Mobile:** at 860px and below, the sidebar becomes a top bar with a bottom tab bar, and skins and sign out move to the avatar menu. At 640px and below, tables become stacked cards and forms go single-column. On phones, PDF previews open in a new tab rather than a modal.

### Lock screen (`/lock`)

Protects a signed-in session from anyone else at the same device.

- **Setup:** users without a lock code are sent to `/lock_settings/edit` and can't use the app until they set one. Codes are 4–8 digits, and trivial ones (`0000`, `1234`, `9876`, …) are rejected. The code is stored as a bcrypt digest (`users.lock_pin_digest`).
- **Locking:** use the 🔒 button in the sidebar or **Ctrl+Shift+L**, or let the app lock itself after the auto-lock period: 1, 5 (default), 15, or 30 minutes, 1 hour, or never. Locking or unlocking in one tab applies to the user's other open tabs.
- **Enforced on the server:** lock state and last activity live on the `sessions` row. While locked, every page, PDF export, and API call is redirected to the lock screen (or answered `423 Locked`). An idle session is locked on its next request even if the browser's timer never fired. Signed-in pages are sent with `Cache-Control: no-store` and the Turbo cache is cleared on lock, so Back can't reveal them.
- **Unlocking:** enter the code on the keypad or keyboard. After 5 wrong codes the session is signed out. A forgotten code can be reset in the lock settings with the account password after signing back in.
- **Changing settings:** the Lock screen card on the profile page links to the settings. Any change needs the current code or the account password.

### Dashboard (`/`)

- Quick-add a todo for **today**. The date is filled in for you.
- Shows the current week by default. Add `?view=month` (optionally `&month=YYYY-MM`) for a monthly view with previous/next navigation.
- Entries are grouped by day with a total hours figure.
- **This month's progress:** hours logged vs the 160h target, hours left to log, activities logged, missed weekdays, a meter with an "expected by today" marker, and a per-day hours chart (logged, holiday, missed, still to log).
- **Last 3 months:** hours logged per month against 160h, with each month's weekday count, logged weekdays, and whether it reached 160h.
- **Holidays:** days logged as public holidays, non-working holidays, or other holidays, for this month and the last 3. There is no holiday field: a day counts when one of its todos mentions "public/regular/national holiday", "non-working", or "holiday" (checked in that order, see `TimeStats::HOLIDAY_KINDS`).

### Verse of the day and daily trivia

The dashboard and the lock screen show a Bible verse (World English Bible) with a short reflection, plus 5 multiple-choice trivia questions about random facts.

- Generated once a day with the FuelIX API (`app/services/fuelix_client.rb`) and stored in `daily_inspirations`, shared by all users. Verses from the last 30 days and recent questions are passed to the AI so they aren't repeated.
- Loaded lazily in a Turbo Frame from `/inspiration`, so a slow AI call never holds up the page. It is served while the screen is locked, because it contains no personal data.
- Trivia progress and score are kept in the browser (localStorage) per day, so the dashboard and lock screen continue the same round.
- If FuelIX isn't configured or fails, a built-in set is shown and the AI is tried again after 30 minutes.
- Settings: `FUELIX_API_KEY`, `FUELIX_API_URL` (default `https://api.fuelix.ai`), and `FUELIX_MODEL` (default `claude-sonnet-4-6`), read from `.env` in development (see `.env.example`). `.env` is git-ignored.

### Manage logs (`/time_entries`)

Create, edit, or delete entries on any date. Shows the 200 most recent entries.

Above the list: this month's and all-time hours, activities, days logged, and activities per day, hours and activities per month for the last 12 months, an 18-week activity heatmap, activities by weekday, and the most logged tasks.

### Timelog export (`/reports`)

Preview and download a PDF timelog (COUNT / DATE / TASK DONE / HOURS WORKED / NOTES table with a total) for:

| Period | Params |
| --- | --- |
| Current month (default) or a specific month | `period=month`, optional `month=YYYY-MM` |
| Previous month | `period=previous_month` |
| Last N days | `period=days&count=N` |
| Last N weeks | `period=weeks&count=N` |
| Custom range | `period=custom&from=YYYY-MM-DD&to=YYYY-MM-DD` |

`N` is clamped to 1–366. Add `inline=1` to `/reports/export` to open the PDF in the browser instead of downloading it.

### Invoices (`/invoices`)

- Charts at the top: invoice count, hours billed, amount billed this year and per month (masked until you press an eye button), billed vs logged hours per month, and a 12-month invoice timeline with the next due date. The amount chart has no value axis, so amounts stay hidden.
- Generate an invoice for a whole month (the last 12 months are listed; the default is the latest finished month), or for a custom date range within one month with its own due date.
- The custom range is prefilled with the first day of the current month that hasn't been invoiced yet, so a partial invoice is easy to follow up.
- Invoices are numbered per user (`INV-001`, `INV-002`, …). Regenerating the same period refreshes the existing invoice instead of creating a new one. Overlapping periods are rejected.
- The invoice is dated the last day of the period and is due on your configured due day of the following month (capped at that month's last day).
- PDFs are US Letter. The "Bill to" block is fixed in `InvoicePdf::BILL_TO` (`app/services/invoice_pdf.rb`).

### Profile (`/profile/edit`)

Name, address, hourly rate, currency (default `PHP`), bank details (account name, number, bank name, SWIFT), and invoice due day (1–31, default 5). Address, hourly rate, and the bank fields must be filled in before you can generate an invoice.

## How hours are calculated

Hours are **not** entered by hand. The app assumes a fixed **160 hours per month** (`Invoice::MONTHLY_HOURS`):

- **Per day:** 160 ÷ the number of weekdays in that month. For example, 20 weekdays gives 8h/day, 21 gives 7.62h, and 22 gives 7.27h. Weekends carry 0 hours.
- **Per entry:** a day's hours are split equally between that day's entries. Adding, moving, or deleting an entry rebalances the day automatically.
- **Invoices:** bill 160h prorated by the weekdays in the invoiced range, whatever has actually been logged. A full month always bills 160h.

## Project layout

| Path | Purpose |
| --- | --- |
| `app/models/time_entry.rb` | Entries and the daily hour-splitting logic |
| `app/models/invoice.rb` | Invoice generation, numbering, and validations |
| `app/models/user.rb` | Account, profile, and invoice due-date rules |
| `app/services/time_stats.rb` | Monthly, holiday, activity, and invoice statistics for the charts |
| `app/views/charts/` | Reusable column chart and meter partials (HTML/CSS, follow the skin) |
| `app/services/report_range.rb` | Turns report params into a date range and label |
| `app/services/timelog_pdf.rb` | Timelog PDF layout |
| `app/services/invoice_pdf.rb` | Invoice PDF layout |
| `app/controllers/concerns/authentication.rb` | Session handling |
| `app/controllers/concerns/screen_lock.rb` | Gates every request behind lock-code setup and the lock screen |
| `app/models/session.rb` | Lock state, server-side auto-lock, failed-attempt limit |
| `app/controllers/locks_controller.rb` | Lock screen, lock, unlock, and activity heartbeat |
| `app/controllers/lock_settings_controller.rb` | Set up or change the lock code and auto-lock period |
| `app/models/theme.rb` | Available skins and the default |
| `app/javascript/controllers/idle_lock_controller.js` | Idle timer, Ctrl+Shift+L, cross-tab lock |
| `app/javascript/controllers/lock_pad_controller.js` | Lock screen keypad and clock |
| `app/javascript/controllers/theme_controller.js` | Instant skin switching |

## Development

    bin/rubocop                # style
    bin/brakeman               # security static analysis
    bin/bundler-audit          # gem vulnerability audit
    bin/ci                     # runs setup and all of the checks above

There is no automated test suite yet.

## Deployment

A production `Dockerfile` is included:

    docker build -t timelog .
    docker run -d -p 80:3000 -e RAILS_MASTER_KEY=<value from config/master.key> --name timelog timelog

The app exposes a health check at `/up`.
