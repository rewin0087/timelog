require "prawn"

# Renders an invoice laid out like the contractor invoice template (US Letter), in one of the PdfStyle designs
# (the invoice's style; the accent colour defaults to grey AAAAAA):
#   classic    - the original template: grey boxed table header
#   modern     - a full-width colour header band, a colour table header, striped rows and a highlighted total
#   minimal    - no fills: accent-coloured title, rules and table header text
#   elegant    - Times, a large italic title, fine double rules and a tinted table header
#   bold       - a colour band down the left edge, an oversized title and a highlighted total
#   executive  - deep header and footer bands with accent stripes, a boxed total
#   aurora     - two-tone gradient header and table header, a gradient footer strip
#   typewriter - Courier with dashed rules
# Coordinates are page points measured from the top-left corner.
class InvoicePdf
  PAGE_H = 792
  LEFT = 73
  COLS = [73, 196, 260, 343, 443, 549].freeze

  ROW_H = 20 # height of each extra item row; everything below the table moves down by this per item

  def initialize(invoice, style: invoice.style)
    @invoice = invoice
    @style = style
    @user = invoice.user
    @items = invoice.items.to_a
    @shift = @items.size * ROW_H
  end

  def render
    @pdf = Prawn::Document.new(page_size: "LETTER", margin: 0)
    header
    dates
    bill_to
    line_item
    totals
    bank_details
    @pdf.render
  end

  private

  def header
    ink = "000000"
    title = { text: "INVOICE", x: 440, y: 70, size: 20, style: (:bold unless @style.classic?) }
    case @style.design
    when "modern"
      fill(@style.color) { @pdf.fill_rectangle [0, PAGE_H], 612, 130 }
      ink = @style.text_color
    when "minimal", "typewriter"
      title[:color] = @style.strong
    when "elegant"
      title.merge!(text: "Invoice", x: 430, y: 60, size: 30, style: :italic, color: @style.strong)
    when "bold"
      fill(@style.color) { @pdf.fill_rectangle [0, PAGE_H], 28, PAGE_H }
      title.merge!(x: 380, y: 58, size: 34, style: :bold, color: @style.strong, width: COLS.last - 380, align: :right)
    when "executive"
      fill(@style.deep) { @pdf.fill_rectangle [0, PAGE_H], 612, 120 }
      fill(@style.color) { @pdf.fill_rectangle [0, PAGE_H - 120], 612, 6 }
      ink = "FFFFFF"
      footer_band
    when "aurora"
      gradient(0, 0, 612, 130)
      gradient(0, PAGE_H - 10, 612, 10)
      ink = @style.text_color
    end
    text @user.name.upcase, LEFT, 80, size: (@style.design == "elegant" ? 14 : 11), style: :bold,
                            color: (@style.design == "elegant" ? @style.strong : ink)
    text @user.address.to_s.gsub(/\s*\r?\n\s*/, ", "), LEFT, 103, size: 8.5, width: 290, color: ink
    text title[:text], title[:x], title[:y], size: title[:size], style: title[:style], color: title[:color] || ink,
                       width: title[:width] || 400, align: title[:align] || :left
    if @style.design == "bold"
      text @invoice.code, 380, 103, size: 10, width: COLS.last - 380, align: :right, color: ink
    else
      text @invoice.code, 476, 103, size: 10, color: ink
    end
    case @style.design
    when "minimal" then rule(LEFT, COLS.last, 128, @style.strong, 1.5)
    when "elegant" then double_rule(LEFT, COLS.last, 128, @style.color)
    when "typewriter" then rule(LEFT, COLS.last, 128, @style.strong, 1, dash: true)
    end
  end

  def footer_band
    fill(@style.deep) { @pdf.fill_rectangle [0, 26], 612, 26 }
    fill(@style.color) { @pdf.fill_rectangle [0, 30], 612, 4 }
    text "Thank you for your business", 0, PAGE_H - 17, size: 8.5, width: 612, align: :center, color: "FFFFFF"
  end

  def dates
    [["Date:", fmt_date(@invoice.invoice_date), 156],
     ["Due Date:", fmt_date(@invoice.due_date), 173],
     ["Balance Due:", "#{@invoice.currency} #{num(@invoice.amount)}", 191]].each do |label, value, y|
      text label, 330, y, size: 10, style: :bold
      text value, 440, y, size: 10
    end
  end

  def bill_to
    text "Bill to:", LEFT, 216, size: 10
    text @user.bill_to_name, LEFT, 242, size: 10, style: :bold
    # Up to 4 address lines fit above the line-item table.
    @user.bill_to_address.to_s.lines.map(&:strip).reject(&:empty?).first(4).each_with_index do |line, i|
      text line, LEFT, 259 + i * 15, size: 10, width: 250
    end
  end

  def line_item
    top = 324
    height = 19
    width = COLS.last - COLS.first
    header_ink = @style.text_color
    case @style.design
    when "minimal"
      rule(COLS.first, COLS.last, top, @style.strong, 1.2)
      rule(COLS.first, COLS.last, top + height, @style.strong, 1.2)
      header_ink = @style.strong
    when "typewriter"
      rule(COLS.first, COLS.last, top, @style.strong, 1, dash: true)
      rule(COLS.first, COLS.last, top + height, @style.strong, 1, dash: true)
      header_ink = @style.strong
    when "elegant"
      fill(@style.tint) { @pdf.fill_rectangle [COLS.first, PAGE_H - top], width, height }
      rule(COLS.first, COLS.last, top, @style.color, 0.75)
      rule(COLS.first, COLS.last, top + height, @style.color, 0.75)
      header_ink = @style.strong
    when "modern"
      fill(@style.color) { @pdf.fill_rectangle [COLS.first, PAGE_H - top], width, height }
    when "bold"
      fill(@style.color) { @pdf.fill_rounded_rectangle [COLS.first, PAGE_H - top], width, height, 4 }
    when "executive"
      fill(@style.deep) { @pdf.fill_rectangle [COLS.first, PAGE_H - top], width, height }
      fill(@style.color) { @pdf.fill_rectangle [COLS.first, PAGE_H - top - height], width, 2 }
      header_ink = "FFFFFF"
    when "aurora"
      gradient(COLS.first, top, width, height)
    else
      fill(@style.color) { @pdf.fill_rectangle [COLS.first, PAGE_H - top], width, height }
      @pdf.stroke_color "000000"
      @pdf.line_width 0.75
      COLS.each_cons(2) { |a, b| @pdf.stroke_rectangle [a, PAGE_H - top], b - a, height }
    end
    %w[ITEM HOURS QUANTITY RATE AMOUNT].each_with_index do |h, i|
      text h, COLS[i], top + 5, size: 10, style: :bold, width: COLS[i + 1] - COLS[i], align: :center, color: header_ink
    end

    y = 361
    if %w[modern bold executive aurora].include?(@style.design) # striped extra item rows
      @items.each_index { |i| fill(@style.tint) { @pdf.fill_rectangle [COLS.first, PAGE_H - (y + 27 + i * ROW_H)], width, ROW_H } if i.even? }
    end
    text @user.invoice_item, COLS[0], y, size: 10, width: COLS[1] - COLS[0] - 4, height: 12
    text @invoice.period_label, COLS[0], y + 13, size: 8, width: COLS[1] - COLS[0] unless @invoice.full_month?
    text num(@invoice.hours), COLS[1] + 15, y, size: 10
    text "1", COLS[2], y, size: 10, width: 58, align: :right
    text money(@invoice.rate), COLS[3], y, size: 10, width: COLS[4] - COLS[3], align: :center
    text money(@invoice.service_amount), COLS[4], y, size: 10, width: COLS[5] - COLS[4], align: :center

    # Extra items (reimbursements, allowances...) below the hours line, after the part-month label.
    @items.each_with_index do |item, i|
      row = y + 32 + i * ROW_H
      text item.description, COLS[0], row, size: 10, width: COLS[1] - COLS[0] - 4, height: 12
      text num(item.quantity), COLS[2], row, size: 10, width: 58, align: :right
      text money(item.rate), COLS[3], row, size: 10, width: COLS[4] - COLS[3], align: :center
      text money(item.amount), COLS[4], row, size: 10, width: COLS[5] - COLS[4], align: :center
    end
  end

  def totals
    total_y = 464 + @shift
    total_ink = "000000"
    box = [322, PAGE_H - (total_y - 5)]
    case @style.design
    when "modern", "bold"
      fill(@style.color) { @pdf.fill_rectangle box, COLS.last - 322, 20 }
      total_ink = @style.text_color
    when "aurora"
      fill(@style.color) { @pdf.fill_rounded_rectangle box, COLS.last - 322, 20, 10 }
      total_ink = @style.text_color
    when "executive"
      fill(@style.tint) { @pdf.fill_rectangle box, COLS.last - 322, 20 }
      @pdf.stroke_color @style.color
      @pdf.line_width 1
      @pdf.stroke_rectangle box, COLS.last - 322, 20
      @pdf.stroke_color "000000"
    when "minimal"
      rule(322, COLS.last, total_y - 6, @style.strong, 1.2)
    when "elegant"
      double_rule(322, COLS.last, total_y - 4, @style.color)
    when "typewriter"
      rule(322, COLS.last, total_y - 6, @style.strong, 1, dash: true)
    end
    [["Subtotal:", money(@invoice.subtotal), 430],
     ["Tax (#{num(@invoice.tax_rate)}%):", @invoice.tax? ? money(@invoice.tax_amount) : "#{@invoice.currency} 0.00", 447],
     ["Total:", money(@invoice.amount), 464]].each do |label, value, y|
      total = label == "Total:"
      text label, 330, y + @shift, size: 10, style: (:bold if total), color: (total ? total_ink : "000000")
      text value, 457, y + @shift, size: 10, style: (:bold if total), color: (total ? total_ink : "000000")
    end
  end

  def bank_details
    top = 499 + @shift
    text "Bank Details:", LEFT, top, size: 10
    [["Bank Account Name:", @user.bank_account_name, 34],
     ["Account Number:", @user.bank_account_number, 51],
     ["Bank Name :", @user.bank_name, 68],
     ["SWIFT:", @user.bank_swift, 85]].each do |label, value, dy|
      text "#{label} <b>#{escape(value)}</b>", LEFT, top + dy, size: 10.5, inline: true, width: 470
    end
    text "Payment Method: Bank Transfer", LEFT, top + 102, size: 10.5
  end

  # Pass height to keep long text on one line (it shrinks to fit instead of wrapping).
  def text(str, x, y_top, size: 10, style: nil, width: 400, height: nil, align: :left, inline: false, color: "000000")
    @pdf.font @style.font, style: style || :normal
    @pdf.fill_color color
    @pdf.text_box str.to_s, at: [x, PAGE_H - y_top], width: width, height: height, size: size, align: align,
                            inline_format: inline, overflow: :shrink_to_fit
    @pdf.fill_color "000000"
  end

  def fill(color)
    @pdf.fill_color color
    yield
    @pdf.fill_color "000000"
  end

  def rule(x1, x2, y_top, color, width, dash: false)
    @pdf.stroke_color color
    @pdf.line_width width
    @pdf.dash(4, space: 3) if dash
    @pdf.stroke_horizontal_line x1, x2, at: PAGE_H - y_top
    @pdf.undash
    @pdf.stroke_color "000000"
  end

  def double_rule(x1, x2, y_top, color)
    rule(x1, x2, y_top, color, 0.6)
    rule(x1, x2, y_top + 2.5, color, 0.6)
  end

  # Fills a rectangle (top-left corner, measured from the page top) with the accent-to-partner gradient.
  def gradient(x, y_top, width, height)
    @pdf.fill_gradient [x, 0], [x + width, 0], @style.color, @style.partner
    @pdf.fill_rectangle [x, PAGE_H - y_top], width, height
    @pdf.fill_color "000000"
  end

  def escape(str) = str.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
  def fmt_date(date) = date.strftime("%B #{date.day}, %Y")

  # 270000 -> "270,000", 1687.5 -> "1,687.5", 12.34 -> "12.34"
  def num(n)
    s = format("%.2f", n).sub(/\.00\z/, "").sub(/(\.\d)0\z/, '\1')
    ActiveSupport::NumberHelper.number_to_delimited(s)
  end

  def money(n)
    prefix = @invoice.currency == "PHP" ? "P" : "#{@invoice.currency} "
    "#{prefix}#{num(n)}"
  end
end
