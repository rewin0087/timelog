require "prawn"
require "prawn/table"

# Timesheet PDF in one of three designs (PdfStyle), all with a title (month, name, covered period) and a
# COUNT / DATE / TASK DONE / HOURS WORKED / NOTES table ending in a TOTAL row:
#   classic - the original paper template: a shaded title band boxed with the table, padded with blank rows
#   modern  - a full-width colour band, a colour table header and striped rows
#   minimal - no fills: accent-coloured title and rules, light row dividers
# The accent colour (header backgrounds) defaults to peach (FBE3D6).
class TimelogPdf
  THICK = 1.5
  THIN = 0.5
  MIN_ROWS = 26
  HEADERS = ["COUNT", "DATE", "TASK DONE", "HOURS WORKED", "NOTES/ REMARKS"].freeze
  COLUMN_WIDTHS = [42, 142, 156, 82, 93].freeze

  def initialize(range, user, style: user.report_style)
    @range = range
    @user = user
    @style = style
    @entries = range.entries(user).to_a
  end

  def render
    pdf = Prawn::Document.new(page_size: "A4", margin: 40)
    case @style.design
    when "modern" then modern_title(pdf)
    when "minimal" then minimal_title(pdf)
    else classic_title(pdf)
    end
    entries_table(pdf)
    pdf.number_pages "Page <page> of <total>", at: [pdf.bounds.right - 100, 0], width: 100, align: :right, size: 8, color: "666666"
    pdf.render
  end

  private

  def classic_title(pdf)
    width = pdf.bounds.width
    top = pdf.cursor
    band_height = 84
    pdf.fill_color @style.color
    pdf.fill_rectangle [0, top], width, band_height
    pdf.fill_color @style.text_color
    pdf.bounding_box([6, top - 6], width: width - 12, height: band_height - 6) do
      pdf.text title, size: 20, style: :bold
      pdf.move_down 6
      pdf.text @user.name.upcase, size: 14, style: :bold
      pdf.move_down 6
      pdf.text "COVERED PERIOD: #{covered_period}", size: 14, style: :bold
    end
    pdf.fill_color "000000"
    pdf.move_down 6 + 24
    pdf.line_width = THICK
    pdf.stroke do
      pdf.move_to 0, pdf.cursor
      pdf.line_to 0, top
      pdf.line_to width, top
      pdf.line_to width, pdf.cursor
    end
  end

  def modern_title(pdf)
    width = pdf.bounds.width
    top = pdf.cursor
    pdf.fill_color @style.color
    pdf.fill_rounded_rectangle [0, top], width, 92, 10
    pdf.fill_color @style.text_color
    pdf.bounding_box([20, top - 18], width: width - 40, height: 70) do
      pdf.text title, size: 22, style: :bold
      pdf.move_down 8
      pdf.text "#{@user.name}  ·  #{covered_period.split.map(&:capitalize).join(' ')}", size: 12
    end
    pdf.fill_color "000000"
    pdf.move_down 24
  end

  def minimal_title(pdf)
    pdf.fill_color @style.strong
    pdf.text title, size: 22, style: :bold
    pdf.fill_color "000000"
    pdf.move_down 4
    pdf.text "#{@user.name.upcase}  ·  #{covered_period}", size: 11, color: "555555"
    pdf.move_down 10
    pdf.stroke_color @style.strong
    pdf.line_width = 2
    pdf.stroke_horizontal_rule
    pdf.stroke_color "000000"
    pdf.move_down 18
  end

  def entries_table(pdf)
    body = @entries.each_with_index.map do |e, i|
      [(i + 1).to_s, e.log_date.strftime("%A, %B %-d, %Y"), e.todo, format("%.2f", e.hours), ""]
    end
    body += Array.new([MIN_ROWS - body.size, 0].max) { Array.new(HEADERS.size, " ") } if @style.classic?
    rows = [HEADERS] + body + [["", "", "TOTAL", format("%.2f", @entries.sum(&:hours)), ""]]

    case @style.design
    when "modern" then modern_table(pdf, rows)
    when "minimal" then minimal_table(pdf, rows)
    else classic_table(pdf, rows)
    end
  end

  def classic_table(pdf, rows)
    style = @style
    pdf.table(rows, header: true, column_widths: COLUMN_WIDTHS,
              cell_style: { size: 9, padding: [4, 4], border_width: THIN, border_color: "000000" }) do |t|
      t.row(0).font_style = :bold
      t.row(0).background_color = style.color
      t.row(0).text_color = style.text_color
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

  def modern_table(pdf, rows)
    style = @style
    last = rows.size - 1
    pdf.table(rows, header: true, column_widths: COLUMN_WIDTHS,
              cell_style: { size: 9, padding: [6, 5], border_width: 0.4, border_color: "DDDDDD" }) do |t|
      t.row(0).font_style = :bold
      t.row(0).size = 8
      t.row(0).background_color = style.color
      t.row(0).text_color = style.text_color
      t.row(0).border_color = style.color
      (1...last).each { |i| t.row(i).background_color = i.even? ? style.tint : "FFFFFF" }
      t.row(-1).font_style = :bold
      t.row(-1).background_color = style.tint
      t.row(-1).border_top_width = 1.2
      t.row(-1).border_top_color = style.strong
      t.column(3).align = :center
    end
  end

  def minimal_table(pdf, rows)
    style = @style
    pdf.table(rows, header: true, column_widths: COLUMN_WIDTHS,
              cell_style: { size: 9, padding: [6, 4], borders: [:bottom], border_width: 0.4, border_color: "E2E2E2" }) do |t|
      t.row(0).font_style = :bold
      t.row(0).size = 8
      t.row(0).text_color = style.strong
      t.row(0).border_bottom_width = 1.5
      t.row(0).border_bottom_color = style.strong
      t.row(-1).font_style = :bold
      t.row(-1).borders = [:top]
      t.row(-1).border_top_width = 1.5
      t.row(-1).border_top_color = style.strong
      t.column(3).align = :center
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
