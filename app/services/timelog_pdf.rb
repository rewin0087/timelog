require "prawn"
require "prawn/table"

# Timesheet layout: a shaded title band (month, name, covered period) boxed together with
# a COUNT / DATE / TASK DONE / HOURS WORKED / NOTES table, padded with blank rows and a TOTAL.
class TimelogPdf
  ACCENT = "FBE3D6"
  THICK = 1.5
  THIN = 0.5
  MIN_ROWS = 26
  HEADERS = ["COUNT", "DATE", "TASK DONE", "HOURS WORKED", "NOTES/ REMARKS"].freeze
  COLUMN_WIDTHS = [42, 142, 156, 82, 93].freeze

  def initialize(range, user)
    @range = range
    @user = user
    @entries = range.entries(user).to_a
  end

  def render
    pdf = Prawn::Document.new(page_size: "A4", margin: 40)
    title_band(pdf)
    entries_table(pdf)
    pdf.number_pages "Page <page> of <total>", at: [pdf.bounds.right - 100, 0], width: 100, align: :right, size: 8
    pdf.render
  end

  private

  def title_band(pdf)
    width = pdf.bounds.width
    top = pdf.cursor
    band_height = 84
    pdf.fill_color ACCENT
    pdf.fill_rectangle [0, top], width, band_height
    pdf.fill_color "000000"
    pdf.bounding_box([6, top - 6], width: width - 12, height: band_height - 6) do
      pdf.text title, size: 20, style: :bold
      pdf.move_down 6
      pdf.text @user.name.upcase, size: 14, style: :bold
      pdf.move_down 6
      pdf.text "COVERED PERIOD: #{covered_period}", size: 14, style: :bold
    end
    pdf.move_down 6 + 24
    pdf.line_width = THICK
    pdf.stroke do
      pdf.move_to 0, pdf.cursor
      pdf.line_to 0, top
      pdf.line_to width, top
      pdf.line_to width, pdf.cursor
    end
  end

  def entries_table(pdf)
    body = @entries.each_with_index.map do |e, i|
      [(i + 1).to_s, e.log_date.strftime("%A, %B %-d, %Y"), e.todo, format("%.2f", e.hours), ""]
    end
    body += Array.new([MIN_ROWS - body.size, 0].max) { Array.new(HEADERS.size, " ") }
    rows = [HEADERS] + body + [["", "", "TOTAL", format("%.2f", @entries.sum(&:hours)), ""]]

    pdf.table(rows, header: true, column_widths: COLUMN_WIDTHS,
              cell_style: { size: 9, padding: [4, 4], border_width: THIN, border_color: "000000" }) do |t|
      t.row(0).font_style = :bold
      t.row(0).background_color = ACCENT
      t.row(-1).font_style = :bold
      t.row(-1).border_bottom_width = THICK
      t.column(0).border_left_width = THICK
      t.column(-1).border_right_width = THICK
      t.column(3).align = :center
    end

    # Second rule just above the closing border gives the TOTAL row its double underline.
    pdf.stroke do
      pdf.line_width = THIN
      pdf.horizontal_line 0, pdf.bounds.width, at: pdf.cursor + 2.5
    end
  end

  def title
    same_month? ? "TIMESHEET - #{@range.from.strftime('%B %Y').upcase}" : "TIMESHEET"
  end

  # e.g. "SEPTEMBER 1 - 30 2026", "AUGUST 25 - SEPTEMBER 10 2026", "DECEMBER 20 2025 - JANUARY 5 2026"
  def covered_period
    from, to = @range.from, @range.to
    text = if from.year != to.year
      "#{from.strftime('%B %-d %Y')} - #{to.strftime('%B %-d %Y')}"
    elsif from.month != to.month
      "#{from.strftime('%B %-d')} - #{to.strftime('%B %-d %Y')}"
    else
      "#{from.strftime('%B %-d')} - #{to.strftime('%-d %Y')}"
    end
    text.upcase
  end

  def same_month?
    @range.from.beginning_of_month == @range.to.beginning_of_month
  end
end
