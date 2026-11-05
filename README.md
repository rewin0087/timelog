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

Open the app, go to **Sign up** (`/signup`), and create an account. Everything after that requires being signed in.

## Features

### Dashboard (`/`)

- Quick-add a todo for **today**. The date is filled in for you.
- Shows the current week by default. Add `?view=month` (optionally `&month=YYYY-MM`) for a monthly view with previous/next navigation.
- Entries are grouped by day with a total hours figure.

### Manage logs (`/time_entries`)

Create, edit, or delete entries on any date. Shows the 200 most recent entries.

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
| `app/services/report_range.rb` | Turns report params into a date range and label |
| `app/services/timelog_pdf.rb` | Timelog PDF layout |
| `app/services/invoice_pdf.rb` | Invoice PDF layout |
| `app/controllers/concerns/authentication.rb` | Session handling |

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
