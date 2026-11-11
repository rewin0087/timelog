class TimelogAgent
  module Tools
    # The user's account and settings. Bank details are left out on purpose.
    class GetAccount < Base
      tool "get_account",
           description: "The user's account and settings: name, currency, hourly rate, how hours are worked out " \
                        "(fixed monthly target or no target), hours per day this month, and invoice defaults."

      def call(_args)
        {
          name: user.name,
          currency: user.currency,
          hourly_rate: user.hourly_rate&.to_f,
          hours_mode: User::HOURS_MODES.fetch(user.hours_mode),
          monthly_target_hours: user.monthly_target&.to_f,
          hours_per_weekday_this_month: hours(user.daily_hours_for(today.beginning_of_month.next_weekday)),
          weekdays_this_month: TimeEntry.weekdays_in_month(today),
          invoice: invoice_defaults,
          first_logged_on: user.time_entries.minimum(:log_date)&.iso8601,
          total_entries: user.time_entries.count,
          total_invoices: user.invoices.count
        }
      end

      private

      def invoice_defaults
        {
          bill_to: user.bill_to_name,
          line_item: user.invoice_item,
          due_day_of_following_month: user.invoice_due_day,
          tax_rate_percent: user.tax_rate.to_f,
          default_hours_basis: Invoice::HOURS_BASES.fetch(Invoice.hours_basis_for(user))
        }
      end
    end
  end
end
