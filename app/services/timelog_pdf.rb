require "prawn"
require "prawn/table"

# Timesheet PDF in one of the PdfStyle designs, all with a title (month, name, covered period) and a
# COUNT / DATE / TASK DONE / HOURS WORKED / NOTES table ending in a TOTAL row:
#   classic    - the original paper template: a shaded title band boxed with the table, padded with blank rows
#   modern     - a full-width colour band, a colour table header and striped rows
#   minimal    - no fills: accent-coloured title and rules, light row dividers
#   elegant    - Times, a centred title between fine double rules, hairline rows
#   bold       - a colour band down the left edge of every page, an oversized title and a colour TOTAL bar
#   executive  - a deep full-bleed header band with an accent stripe, a total-hours figure and a page footer
#   aurora     - a two-tone gradient header card and soft striped rows
#   typewriter - Courier, form-style labels and dashed rules
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
    pdf = Prawn::Document.new(page_size: "A4", margin: @style.design == "bold" ? [40, 40, 40, 64] : 40)
    pdf.font @style.font
    send("#{@style.design}_title", pdf)
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
      pdf.text "#{@user.name}  ·  #{titlecase(covered_period)}", size: 12
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
      [(i + 1).to_s, e.log_date.strftime(@style.design == "typewriter" ? "%a, %b %-d, %Y" : "%A, %B %-d, %Y"), e.todo, format("%.2f", e.hours), remark(e)]
    end
    body += Array.new([MIN_ROWS - body.size, 0].max) { Array.new(HEADERS.size, " ") } if @style.classic?
    rows = [HEADERS] + body + [["", "", "TOTAL", format("%.2f", @entries.sum(&:hours)), ""]]

    send("#{@style.design}_table", pdf, rows)
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

  def elegant_title(pdf)
    double_rule(pdf, @style.color)
    pdf.move_down 16
    pdf.text title, size: 22, style: :bold, align: :center, color: @style.strong, character_spacing: 1.5
    pdf.move_down 6
    pdf.text @user.name.upcase, size: 11, align: :center, color: "444444", character_spacing: 3
    pdf.move_down 3
    pdf.text titlecase(covered_period), size: 11, style: :italic, align: :center, color: "666666"
    pdf.move_down 14
    double_rule(pdf, @style.color)
    pdf.move_down 20
  end

  def elegant_table(pdf, rows)
    style = @style
    pdf.table(rows, header: true, column_widths: COLUMN_WIDTHS,
              cell_style: { size: 9.5, padding: [6, 5], borders: [:bottom], border_width: 0.3, border_color: "D9D4CC" }) do |t|
      t.row(0).font_style = :bold
      t.row(0).size = 8.5
      t.row(0).text_color = style.strong
      t.row(0).background_color = style.tint
      t.row(0).borders = [:top, :bottom]
      t.row(0).border_width = 0.75
      t.row(0).border_color = style.color
      t.row(-1).font_style = :bold
      t.row(-1).borders = [:top, :bottom]
      t.row(-1).border_width = 0.75
      t.row(-1).border_color = style.color
      t.column(3).align = :center
    end
    pdf.move_down 2
    pdf.stroke_color @style.color
    pdf.line_width = 0.75
    pdf.stroke_horizontal_rule
    pdf.stroke_color "000000"
  end

  def bold_title(pdf)
    style = @style
    pdf.repeat(:all) do
      pdf.canvas do
        pdf.fill_color style.color
        pdf.fill_rectangle [0, pdf.bounds.top], 24, pdf.bounds.height
        pdf.fill_color "000000"
      end
    end
    pdf.text title, size: 26, style: :bold, color: @style.strong
    pdf.move_down 10
    pill = "#{@user.name.upcase}   #{covered_period}"
    width = 0
    pdf.font(@style.font, style: :bold) { width = pdf.width_of(pill, size: 10) + 28 }
    top = pdf.cursor
    pdf.fill_color @style.color
    pdf.fill_rounded_rectangle [0, top], width, 22, 11
    pdf.fill_color @style.text_color
    pdf.font(@style.font, style: :bold) { pdf.text_box pill, at: [14, top - 6], width: width - 20, height: 12, size: 10, overflow: :shrink_to_fit }
    pdf.fill_color "000000"
    pdf.move_down 22 + 22
  end

  def bold_table(pdf, rows)
    style = @style
    pdf.table(rows, header: true, column_widths: [46, 134, 150, 80, 81], # narrower page: the side band takes 24pt
              cell_style: { size: 9, padding: [7, 6], borders: [:bottom], border_width: 0.5, border_color: "E5E5E5" }) do |t|
      t.row(0).font_style = :bold
      t.row(0).size = 8.5
      t.row(0).background_color = style.color
      t.row(0).text_color = style.text_color
      t.row(0).border_color = style.color
      t.row(-1).font_style = :bold
      t.row(-1).size = 10
      t.row(-1).background_color = style.color
      t.row(-1).text_color = style.text_color
      t.row(-1).border_color = style.color
      t.column(0).font_style = :bold
      t.column(3).align = :center
    end
  end

  def executive_title(pdf)
    style = @style
    name = @user.name
    total = format("%.2f", @entries.sum(&:hours))
    pdf.canvas do
      w, h = pdf.bounds.width, pdf.bounds.top
      pdf.fill_color style.deep
      pdf.fill_rectangle [0, h], w, 112
      pdf.fill_color style.color
      pdf.fill_rectangle [0, h - 112], w, 6
      pdf.fill_color "FFFFFF"
      pdf.text_box title, at: [40, h - 32], width: 360, size: 20, style: :bold
      pdf.text_box "#{name}  ·  #{titlecase(covered_period)}", at: [40, h - 62], width: 360, size: 11
      pdf.text_box "TOTAL HOURS", at: [w - 180, h - 34], width: 140, size: 8, align: :right, character_spacing: 1.5
      pdf.text_box total, at: [w - 180, h - 48], width: 140, size: 26, style: :bold, align: :right
      pdf.fill_color "000000"
    end
    pdf.repeat(:all) do
      pdf.stroke_color style.color
      pdf.line_width = 1
      pdf.stroke_horizontal_line 0, pdf.bounds.width, at: 14
      pdf.stroke_color "000000"
      pdf.text_box "#{name} · Timesheet", at: [0, 10], width: 300, size: 8, color: "666666"
    end
    pdf.move_cursor_to pdf.bounds.height - 106
  end

  def executive_table(pdf, rows)
    style = @style
    last = rows.size - 1
    pdf.table(rows, header: true, column_widths: COLUMN_WIDTHS,
              cell_style: { size: 9, padding: [6, 5], borders: [:bottom], border_width: 0.4, border_color: "DDDDDD" }) do |t|
      t.row(0).font_style = :bold
      t.row(0).size = 8
      t.row(0).background_color = style.deep
      t.row(0).text_color = "FFFFFF"
      t.row(0).border_bottom_width = 2
      t.row(0).border_bottom_color = style.color
      (1...last).each { |i| t.row(i).background_color = i.even? ? style.tint : "FFFFFF" }
      t.row(-1).font_style = :bold
      t.row(-1).border_bottom_width = 2
      t.row(-1).border_bottom_color = style.deep
      t.column(3).align = :center
    end
  end

  def aurora_title(pdf)
    width = pdf.bounds.width
    top = pdf.cursor
    # Gradient end points are page coordinates; the card sits inside the 40pt margins.
    pdf.fill_gradient [40, 0], [40 + width, 0], @style.color, @style.partner
    pdf.fill_rounded_rectangle [0, top], width, 96, 14
    pdf.fill_color @style.text_color
    pdf.bounding_box([22, top - 20], width: width - 44, height: 70) do
      pdf.text title, size: 22, style: :bold
      pdf.move_down 8
      pdf.text "#{@user.name}  ·  #{titlecase(covered_period)}", size: 12
    end
    pdf.fill_color "000000"
    pdf.move_down 26
  end

  def aurora_table(pdf, rows)
    style = @style
    last = rows.size - 1
    pdf.table(rows, header: true, column_widths: COLUMN_WIDTHS,
              cell_style: { size: 9, padding: [7, 6], borders: [], border_width: 0 }) do |t|
      t.row(0).font_style = :bold
      t.row(0).size = 8
      t.row(0).background_color = style.color
      t.row(0).text_color = style.text_color
      (1...last).each { |i| t.row(i).background_color = i.even? ? style.tint : "FFFFFF" }
      t.row(-1).font_style = :bold
      t.row(-1).background_color = style.partner
      t.row(-1).text_color = style.text_color
      t.column(3).align = :center
    end
  end

  def typewriter_title(pdf)
    pdf.text title, size: 18, style: :bold, color: @style.strong
    pdf.move_down 8
    pdf.text "NAME   : #{@user.name.upcase}", size: 10
    pdf.text "PERIOD : #{covered_period}", size: 10
    pdf.move_down 10
    pdf.stroke_color @style.strong
    pdf.line_width = 1
    pdf.dash(4, space: 3)
    pdf.stroke_horizontal_rule
    pdf.undash
    pdf.stroke_color "000000"
    pdf.move_down 18
  end

  def typewriter_table(pdf, rows)
    style = @style
    pdf.table(rows, header: true, column_widths: COLUMN_WIDTHS,
              cell_style: { size: 8.5, padding: [5, 4], borders: [:bottom], border_width: 0.5, border_color: "BBBBBB",
                            border_lines: [:dotted] * 4 }) do |t|
      t.row(0).font_style = :bold
      t.row(0).text_color = style.strong
      t.row(0).borders = [:top, :bottom]
      t.row(0).border_width = 1
      t.row(0).border_color = style.strong
      t.row(0).border_lines = [:dashed] * 4
      t.row(-1).font_style = :bold
      t.row(-1).borders = [:top, :bottom]
      t.row(-1).border_width = 1
      t.row(-1).border_color = style.strong
      t.row(-1).border_lines = [:solid] * 4
      t.column(3).align = :center
    end
  end

  def double_rule(pdf, color)
    pdf.stroke_color color
    pdf.line_width = 0.75
    pdf.stroke_horizontal_rule
    pdf.move_down 2.5
    pdf.stroke_horizontal_rule
    pdf.stroke_color "000000"
  end

  def titlecase(text) = text.split.map(&:capitalize).join(" ")

  # NOTES column: marks leave and unpaid days (see DayKind).
  def remark(entry)
    kind = entry.day_kind
    return "" unless kind
    kind.billable ? kind.label : "Unpaid - not billable"
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
