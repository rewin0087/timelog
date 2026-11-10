# Timelog (Time.log)

A small Rails 8 app for contractors to log daily work, export timesheet PDFs, and generate invoices. Each user has their own account, entries, and invoices. It is shown to users as **Time.log**; the codebase keeps the `Timelog` name. A separate admin back office (`/admin`) manages every user's data.

## Stack

- Ruby 3.4.9, Rails 8.1
- PostgreSQL
- Hotwire (Turbo + Stimulus), import maps, Propshaft
- [Prawn](https://github.com/prawnpdf/prawn) + prawn-table for PDF generation
- Rails' built-in authentication (`has_secure_password`, cookie-backed sessions)

## Getting started

Prerequisites: Ruby 3.4.9 and a running PostgreSQL server (the dev database is `timelog_development`, using your OS user as the role by default; see `config/database.yml`).

    bundle install
    bin/rails db:create db:migrate db:seed
    bin/rails s     # http://localhost:3000

Or run `bin/setup` to install gems, prepare the database, and start the server in one step.

Open the app and choose **Sign up** (`/signup`). After creating an account you go through a two-step [onboarding](#onboarding-onboarding) (invoice details, then a lock code). Everything after that requires being signed in, onboarded, and unlocked.

For the admin, sign in at `/admin`. In development, `db:seed` creates a super admin `admin@example.com` / `admin-password`. Elsewhere, create one with:

    bin/rails admin:create EMAIL=you@example.com PASSWORD=a-long-password NAME="Your Name"

## Features

### Landing, layout, skins, and mobile

- **Landing:** sign in (`/session/new`) and sign up share a landing page with the Time.log intro, feature cards, an animated preview card, and an animated background (drifting colour blobs, a moving grid, rising rings). The animations are switched off when the system asks for reduced motion.
- **Navigation** lives in a left sidebar. Page changes use the View Transitions API: the old page slides off one window edge while the new one slides in from the other, both moving together. Moving down the sidebar (or forward) slides in from the right; moving up, or the browser's Back button, slides in from the left. The distance is measured from the page to the window edge, so it reaches the edges on any screen width. Visits to the same page (form saves, month paging) cross-fade instead. Lock and unlock use a shutter animation.
- **Skins:** 13 colour themes, picked from the swatches in the sidebar: Violet (default), Ocean, Sunset, Forest, Candy, Midnight, Rainbow, Lemonade, Ruby, Slate, Mocha, Neon, and Aurora. Midnight, Neon, and Aurora are dark. The choice is saved in the Rails session, so it resets to Violet after signing out. Skins are listed in `app/models/theme.rb` and defined as CSS custom properties in `app/assets/stylesheets/application.css`.
- **Mobile:** at 860px and below, the sidebar becomes a top bar with a bottom tab bar, and skins and sign out move to the avatar menu. At 640px and below, tables become stacked cards and forms go single-column. On phones, PDF previews open in a new tab rather than a modal.

### Onboarding (`/onboarding`)

New users can't use the app until two required steps are done (`User#onboarded?`); every page redirects here until then.

1. **Invoice details:** name, address, client (bill to) name and address, invoice item, hourly rate, currency, due day, default tax rate, working hours, and bank details.
2. **Lock screen:** a 4–8 digit lock code and the auto-lock period.

Users who already have one part (for example, created in the admin with invoice details) are only asked for the other. When both are done they continue to the page they first asked for.

### Lock screen (`/lock`)

Protects a signed-in session from anyone else at the same device.

- **Setup:** the lock code is chosen during onboarding. Codes are 4–8 digits, and trivial ones (`0000`, `1234`, `9876`, …) are rejected. The code is stored as a bcrypt digest (`users.lock_pin_digest`).
- **Locking:** use the 🔒 button in the sidebar or **Ctrl+Shift+L**, or let the app lock itself after the auto-lock period: 1, 5 (default), 15, or 30 minutes, 1 hour, or never. Locking or unlocking in one tab applies to the user's other open tabs.
- **Enforced on the server:** lock state and last activity live on the `sessions` row. While locked, every page, PDF export, and API call is redirected to the lock screen (or answered `423 Locked`). An idle session is locked on its next request even if the browser's timer never fired. Signed-in pages are sent with `Cache-Control: no-store` and the Turbo cache is cleared on lock, so Back can't reveal them.
- **Unlocking:** enter the code on the keypad or keyboard. After 5 wrong codes the session is signed out.
- **Changing settings:** the Lock screen card on the profile page changes the code or the auto-lock period. Any change needs the current code or the account password, so a forgotten code can be reset with the password.

### Dashboard (`/`)

- Quick-add a todo for **today**. The date is filled in for you.
- Shows the current week by default. **Month report** (`?view=month`, optionally `&month=YYYY-MM`) shows a month with previous/next navigation.
- The activity list can be shown as a **Table** or a **Timeline** (one node per day with its todos and hours, today highlighted). The choice (`?display=table|timeline`) is remembered for the session.
- **This month's progress:** hours logged vs the target, hours left to log, activities logged, missed weekdays, a meter with an "expected by today" marker, and a per-day hours chart (logged, holiday, missed, still to log).
- **Last 3 months:** hours logged per month against the target, with each month's weekday count, logged weekdays, and whether it reached the target.
- **Holidays & leave:** days logged as public holidays, non-working holidays, other holidays, paid leave, or unpaid days, for this month and the last 3 (see [Holidays and leave](#holidays-and-leave)).

### Holidays and leave

There is no holiday or leave field: the todo's wording decides the kind (`DayKind`, checked in this order, case-insensitive, anywhere in the todo):

| Kind | Wording | Hours and billing |
| --- | --- | --- |
| Unpaid / absent | "Absent", "Unpaid sick leave", "Unpaid vacation (leave)", "Unpaid holiday", "Unpaid leave" | Logged at **0h** and never billed. The day still counts as logged, so it isn't "missed". |
| Public holiday | "Public / Regular / National holiday" | A full working day, billed |
| Non-working holiday | "Non-working" | A full working day, billed |
| Paid leave | "Paid holiday", "On vacation", "Sick leave", "Paid sick leave", "Paid vacation leave", "Vacation leave", "Paid leave" | A full working day, billed |
| Holiday | any other "holiday" | A full working day, billed |

- A day is unpaid only when **all** of its todos are unpaid; a day with work and an "absent" note is still a working day (the unpaid todo gets 0h and the others share the day).
- Unpaid weekdays aren't owed: they come off the month's target for progress, "hours left", and "expected by today" (`TimeStats::Month#billable_target`), and invoices from time logs don't bill them. An invoice at the fixed monthly rate skips time logs, so it doesn't deduct them.
- Charts colour each kind (unpaid days are hatched grey), the timesheet PDF notes them in the NOTES/REMARKS column ("Paid leave", "Unpaid - not billable"), and the log forms list the wording under "Logging holidays and leave".

### Verse of the day and daily trivia

The dashboard and the lock screen show a Bible verse (World English Bible) with a short reflection, plus 5 multiple-choice trivia questions about random facts.

- Generated once a day with the FuelIX API (`app/services/fuelix_client.rb`) and stored in `daily_inspirations`, shared by all users. Verses from the last 30 days and recent questions are passed to the AI so they aren't repeated.
- Loaded lazily in a Turbo Frame from `/inspiration`, so a slow AI call never holds up the page. It is served while the screen is locked, because it contains no personal data.
- Trivia progress and score are kept in the browser (localStorage) per day, so the dashboard and lock screen continue the same round.
- If FuelIX isn't configured or fails, a built-in set is shown and the AI is tried again after 30 minutes.
- Settings: `FUELIX_API_KEY`, `FUELIX_API_URL` (default `https://api.fuelix.ai`), and `FUELIX_MODEL` (default `claude-sonnet-4-6`), read from `.env` in development (see `.env.example`). `.env` is git-ignored.

### Manage logs (`/time_entries`)

Create, edit, or delete entries on any date. Shows the 200 most recent entries, with page links (`?page=N`) to older ones.

Above the list (first page only): this month's and all-time hours, activities, days logged, and activities per day, hours and activities per month for the last 12 months, an 18-week activity heatmap, activities by weekday, and the most logged tasks.

### Timesheet export (`/reports`)

Preview and download a timesheet PDF (COUNT / DATE / TASK DONE / HOURS WORKED / NOTES table with a total) for:

| Period | Params |
| --- | --- |
| Current month (default) or a specific month | `period=month`, optional `month=YYYY-MM` |
| Previous month | `period=previous_month` |
| Last N days | `period=days&count=N` |
| Last N weeks | `period=weeks&count=N` |
| Custom range | `period=custom&from=YYYY-MM-DD&to=YYYY-MM-DD` |

`N` is clamped to 1–366. Add `inline=1` to `/reports/export` to open the PDF in the browser instead of downloading it. Pick the [PDF design and colour](#pdf-designs-and-colours) with `design=` and `color=` (under **Customize** on the form, which also applies to the admin timesheet export).

When the period has logs, an overview sits above the entries: hours logged vs expected, activities, weekdays logged, missed weekdays, hours per day (per week up to 26 weeks, per month beyond), activities by weekday, and the most logged tasks.

### Invoices (`/invoices`)

- Charts at the top: invoice count, hours billed, amount billed this year and per month (masked until you press an eye button), billed vs logged hours per month, and a 12-month invoice timeline with the next due date. The amount chart has no value axis, so amounts stay hidden.
- **Generate invoice** is one form. Only the period is shown up front; the optional settings below (hours to bill, extra items, tax, PDF style) sit in a collapsible **Customize** section, which is submitted with its defaults when left closed and shows a "Customized" badge when anything in it was changed (`shared/_customize`). Pick a month (the last 12 are listed; the default is the latest finished month) or **Custom dates…** (a range within one month, with its own due date). The custom range is prefilled with the first day of the current month that hasn't been invoiced yet.
- **Hours to bill** (fixed monthly target only): **From time logs** bills the billable hours logged in the period (unpaid leave, absent days, and days with nothing logged add nothing), or **Fixed monthly rate (skip time logs)** bills the target prorated by the period's weekdays, whatever was logged. The form starts with the account default ("Hours to bill (default)" in the invoice details and onboarding, from time logs unless changed). Without a monthly target the choice is hidden and invoices always bill the hours logged. The invoice stores the basis it used (`invoices.hours_basis`).
- **Extra items (optional):** up to 8 extra lines (description, quantity, rate), e.g. reimbursements or allowances, on top of the hours charge.
- **Tax rate:** prefilled from the profile's default tax rate (0 unless set) and can be changed per invoice.
- **PDF style:** a [design and colour](#pdf-designs-and-colours), defaulting to the profile's invoice style. The invoice stores the style it was generated with.
- **Preview PDF** renders the draft invoice exactly as it would be generated, without saving anything (`/invoices/preview`). If the form isn't valid yet (e.g. overlapping dates), the preview explains why.
- Invoices are numbered per user (`INV-001`, `INV-002`, …). Regenerating the same period refreshes the existing invoice, replacing its extra items, tax, and style with what is in the form. Overlapping periods are rejected.
- The invoice is dated the last day of the period and is due on the configured due day of the following month (capped at that month's last day), or on the date picked for custom dates.
- **Amounts:** the invoice total is the hours charge (hours × rate) plus extra items plus tax (`Invoice#amount`); lists, charts, and the PDF all use the total.
- PDFs are US Letter. The "Bill to" block comes from the client name and address in the invoice details (up to 4 address lines are printed).

### PDF designs and colours

Timesheets and invoices can be generated in eight designs (`PdfStyle::DESIGNS`), each with an accent colour for the header and table-header backgrounds:

| Design | Look |
| --- | --- |
| Classic (default) | The original templates: a boxed timesheet with a shaded title band (padded to 26 rows), and the invoice with a shaded boxed table header |
| Modern | A full-width colour header, a colour table header, striped rows; invoices also highlight the total |
| Minimal | No fills: the title, table header, and rules use the accent colour |
| Elegant | Times serif type, a centred title (an italic "Invoice") between fine double rules, a tinted table header |
| Bold | A colour band down the left edge, an oversized title, a colour total bar |
| Executive | A deep header band with an accent stripe (timesheets show total hours in it), a page footer; invoices box the total |
| Aurora | A two-tone gradient header from the accent to a hue-shifted partner, soft striped rows |
| Typewriter | Courier type, form-style labels and dashed rules |

- **Colour:** one of 10 presets or any colour from the picker. The defaults keep the original look: peach `#FBE3D6` for timesheets and grey `#AAAAAA` for invoices. Header text turns white on dark colours, pale colours are deepened for lines and text (Minimal, Elegant, Typewriter), and the Executive and Aurora shades are derived from the accent so text stays readable.
- **Defaults per account:** "PDF style defaults" in the profile's invoice details (one for timesheets, one for invoices). Forms start with these selected.
- **Per export or invoice:** the Export report, Generate invoice, and admin forms each have the picker: design cards with a mini preview tinted in the chosen colour. The PDF previews show the result.

### Profile (`/profile/edit`)

Separate forms, each saved on its own:

- **Profile:** name, address (printed at the top of invoices), and working hours (fixed monthly target or no target, see below).
- **Invoice details:** client (bill to) name and address, invoice item (default "Consultancy Service"), hourly rate, currency (default `PHP`), default tax rate (default 0%), default hours to bill (from time logs or fixed monthly rate), invoice due day (1–31, default 5), bank details (account name, number, bank name, SWIFT), and PDF style defaults. Address, client, hourly rate, and bank fields are required.
- **Lock screen:** change the code or auto-lock period (needs the current code or account password).
- **Password:** change the account password (needs the current password). Other signed-in devices are signed out.

## Admin back office (`/admin`)

A separate area for managing all data, with its own accounts (`Administrator`), sign-in cookie, and layout. App users can't sign in there, and the app's screen lock doesn't apply.

### Access levels

| Level | View | Create | Edit | Delete, reveal bank details, manage administrators |
| --- | --- | --- | --- | --- |
| View only | ✓ | | | |
| View + create | ✓ | ✓ | | |
| View + edit | ✓ | | ✓ | |
| View + create + edit | ✓ | ✓ | ✓ | |
| All access (super admin) | ✓ | ✓ | ✓ | ✓ |

Permissions are checked on the server for every action (`Administrator#can?`). The last super admin can't be removed or downgraded, and nobody can delete their own account. Administrator passwords need at least 10 characters; admin sessions expire after 12 hours.

### Screens

- **Dashboard:** users, active users this month, hours this month, invoices, and users still onboarding; hours logged per month, active users and sign-ups per month, invoices per month with totals per currency, a top-users leaderboard, and the latest timelogs from every user.
- **Users:** search and paginate (25 per page), with each user's status, this month's hours against their target, timelog and invoice counts, and last log. Inside a user:
  - **Overview:** that user's charts (the same as their Manage logs page), missed weekdays, last log, invoiced total, recent invoices.
  - **Timelogs:** a month-by-month timeline with add, edit, and delete, and a timesheet PDF export for any report period and style.
  - **Invoices:** billed vs logged hours, and the same Generate invoice form as the app (month or custom dates, extra items, tax, style, draft preview), plus preview, download, and delete.
  - **Details:** edit the account, profile, invoicing, PDF style defaults, and bank details; reset the lock code; sign out everywhere; delete the user (with all their data).
- **Administrators** (super admins only): create, edit access levels, and remove administrator accounts.
- **Light / dark skin** toggle in the sidebar, saved in the admin session.

**Masked data:** bank details are always shown partly hidden (e.g. `••••••5678`). Only super admins receive the full values (behind an eye button); for other levels the full values are never sent to the browser. Bank fields on the edit form start empty, and blank fields keep the stored values.

## How hours are calculated

Hours are **not** entered by hand. Each user picks one of two rules under **Working hours** in their profile:

**Fixed monthly target** (default). The month's target, 160h unless the user sets their own (`users.monthly_hours`), is spread over its weekdays:

- **Per day:** target ÷ the number of weekdays in that month. With 160h, 20 weekdays gives 8h/day, 21 gives 7.62h, and 22 gives 7.27h. Weekends carry 0 hours.
- **Invoices:** by default, bill the billable hours logged in the range (so a fully logged month with no unpaid days bills the full target). Choosing the fixed monthly rate instead bills the target prorated by the weekdays in the range, skipping time logs (see [Invoices](#invoices-invoices)). Either way, an invoice from time logs with nothing billable logged is refused.

**No monthly target** (`hours_mode = "daily"`). There is no monthly limit; each day is capped at 8h (`User::DAILY_HOURS`):

- **Per day:** every logged weekday counts 8h. Weekends carry 0 hours.
- **Invoices:** bill the hours actually logged in the range. An invoice for a range with nothing logged is refused.

In both modes a day's hours are split equally between that day's billable entries (unpaid leave and absent entries get 0h, see [Holidays and leave](#holidays-and-leave)), and adding, moving, or deleting an entry rebalances the day. Changing the rule or the target recalculates the hours on all existing entries; invoices already generated keep their hours until they are generated again.

## Project layout

| Path | Purpose |
| --- | --- |
| `app/models/time_entry.rb` | Entries and the daily hour-splitting logic |
| `app/models/day_kind.rb` | Holiday and leave kinds from the todo wording, and which are billable |
| `app/models/invoice.rb` | Invoice generation and draft previews, numbering, totals, validations |
| `app/models/invoice_item.rb` | Extra invoice lines (description, quantity, rate) |
| `app/models/user.rb` | Account, profile, required invoice details, onboarding state, PDF style defaults |
| `app/models/pdf_style.rb` | PDF designs and accent colours (defaults, presets, contrast) |
| `app/models/administrator.rb`, `admin_session.rb` | Admin accounts, access levels, admin sessions |
| `app/services/time_stats.rb` | Per-user monthly, holiday, activity, range, and invoice statistics for the charts |
| `app/services/admin_stats.rb` | Statistics across all users for the admin |
| `app/services/report_range.rb` | Turns report params into a date range and label |
| `app/services/timelog_pdf.rb` | Timesheet PDF in each design |
| `app/services/invoice_pdf.rb` | Invoice PDF in each design |
| `app/views/charts/` | Reusable column chart and meter partials (HTML/CSS, follow the skin) |
| `app/controllers/concerns/authentication.rb` | Session handling |
| `app/controllers/concerns/screen_lock.rb` | Gates every request behind onboarding and the lock screen |
| `app/controllers/concerns/invoice_generation.rb` | Generate-invoice form handling shared by the app and the admin |
| `app/controllers/onboardings_controller.rb` | The two onboarding steps |
| `app/controllers/lock_settings_controller.rb`, `passwords_controller.rb` | Lock settings and password changes from the profile |
| `app/controllers/admin/` | Admin back office (base controller with sign-in and permission checks) |
| `app/models/session.rb` | Lock state, server-side auto-lock, failed-attempt limit |
| `app/controllers/locks_controller.rb` | Lock screen, lock, unlock, and activity heartbeat |
| `app/models/theme.rb` | Available skins and the default |
| `app/javascript/application.js` | Page slide direction and distance |
| `app/javascript/controllers/idle_lock_controller.js` | Idle timer, Ctrl+Shift+L, cross-tab lock |
| `app/javascript/controllers/lock_pad_controller.js` | Lock screen keypad and clock |
| `app/javascript/controllers/theme_controller.js` | Instant skin switching |
| `app/javascript/controllers/invoice_items_controller.js` | Add/remove extra invoice item rows |
| `app/javascript/controllers/color_presets_controller.js` | PDF colour swatches |
| `lib/tasks/admin.rake` | `bin/rails admin:create` |

## Development

    bin/rubocop                # style
    bin/brakeman               # security static analysis
    bin/bundler-audit          # gem vulnerability audit
    bundle exec rspec          # full test suite
    bin/ci                     # runs setup, the checks above, and the tests

## Tests

RSpec, with FactoryBot, Capybara + [Cuprite](https://github.com/rubycdp/cuprite) (headless Chrome, which must be installed), WebMock, and pdf-inspector.

| Path | Covers |
| --- | --- |
| `spec/models` | Validations, lock codes, sessions and auto-lock, hour balancing, holiday and leave kinds (paid vs unpaid), invoice generation and totals, PDF styles, administrator access levels, daily inspiration and its fallback |
| `spec/services` | Report periods, timesheet and invoice PDF contents and colours in each design, FuelIX client, chart and range statistics |
| `spec/helpers` | Chart helpers (ticks, percentages, hour/money formatting, masking) |
| `spec/requests` | Every endpoint: sign in/up/out, onboarding, screen lock, lock settings and password, profile forms, skins, dashboard, logs, reports, invoices (extra items, tax, styles, draft preview), other users' data |
| `spec/requests/admin` | Admin sign-in, permissions per access level, dashboard, users, timelogs, export, invoices, masking, administrators, skin |
| `spec/system` | Browser flows: onboarding, quick add, logs CRUD, report period fields and PDF preview, invoices (masking, custom dates with extra items, draft preview with a style), lock screen keypad and shortcut, skins, trivia, mobile layout |

- The factory's default user is fully onboarded (invoice details and a lock code) and bills from time logs. Use `:fixed_rate` for a user whose invoices bill the fixed monthly rate, and `:without_lock`, `:without_invoice_details`, or `:new_signup` for users still onboarding.
- `pdf_text` and `pdf_colors` (in `spec/support/pdf_helpers.rb`) read a PDF's text and the hex colours it uses.
- Every example runs at a fixed time (Friday 13 November 2026, 10:00). Tag an example with `at: Time.zone.local(...)` to change it.
- Tests never call FuelIX: `FUELIX_API_KEY` is cleared and outside network access is blocked; stub it with the helpers in `spec/support/fuelix_helpers.rb`.
- Browser tests are tagged `:js` (desktop window) or `:mobile` (390×844). Run with `HEADFUL=1` to watch them. Failure screenshots land in `tmp/capybara/`.
- Not covered: the rate limits on sign-in, unlock, lock settings, password, and admin sign-in (the test cache store is a null store, so they never trigger), the idle timer firing after minutes of real inactivity, cross-tab lock/unlock messages, and how page transitions look.

## Deployment

A production `Dockerfile` is included:

    docker build -t timelog .
    docker run -d -p 80:3000 -e RAILS_MASTER_KEY=<value from config/master.key> --name timelog timelog

After deploying, run `bin/rails db:migrate`, and create the first super admin with `bin/rails admin:create EMAIL=... PASSWORD=... NAME=...` (the development seed doesn't run in production). The app exposes a health check at `/up`.
