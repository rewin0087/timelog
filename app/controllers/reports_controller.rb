class ReportsController < ApplicationController
  def new
    @range = ReportRange.new(params)
    @entries = @range.entries(Current.user)
  end

  def export
    range = ReportRange.new(params)
    send_data TimelogPdf.new(range, Current.user).render,
              filename: range.filename, type: "application/pdf", disposition: params[:inline].present? ? "inline" : "attachment"
  end
end
