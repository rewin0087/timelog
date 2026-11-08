class ReportsController < ApplicationController
  def new
    @range = ReportRange.new(params)
    @entries = @range.entries(Current.user)
    stats = TimeStats.new(Current.user)
    @overview = stats.range(@range.from, @range.to)
    @expected = stats.expected_between(@range.from, @range.to)
    @missed = stats.missed_between(@range.from, @range.to)
  end

  def export
    range = ReportRange.new(params)
    send_data TimelogPdf.new(range, Current.user, style: PdfStyle.from(:report, params, Current.user)).render,
              filename: range.filename, type: "application/pdf", disposition: params[:inline].present? ? "inline" : "attachment"
  end
end
