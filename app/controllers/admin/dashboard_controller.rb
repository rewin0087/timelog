class Admin::DashboardController < Admin::BaseController
  def show
    stats = AdminStats.new
    @totals = stats.totals
    @months = stats.months(12)
    @signups = stats.signups(12)
    @invoice_months = stats.invoices(12)
    @invoiced = stats.invoiced_by_currency(12)
    @top_users = stats.top_users
    @recent = stats.recent_entries
  end
end
