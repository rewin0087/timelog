require "prawn"

# Renders an invoice laid out like the contractor invoice template (US Letter).
# Coordinates are page points measured from the top-left corner.
class InvoicePdf
  BILL_TO = ["Avvoka Limited", "124 City Road", "EC1V 2NX London", "United Kingdom"].freeze
  PAGE_H = 792
  LEFT = 73
  COLS = [73, 196, 260, 343, 443, 549].freeze

  def initialize(invoice)
    @invoice = invoice
    @user = invoice.user
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
    text @user.name.upcase, LEFT, 80, size: 11, style: :bold
    text @user.address.to_s.gsub(/\s*\r?\n\s*/, ", "), LEFT, 103, size: 8.5, width: 290
    text "INVOICE", 440, 70, size: 20
    text @invoice.code, 476, 103, size: 10
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
    BILL_TO.each_with_index do |line, i|
      text line, LEFT, 242 + i * 17, size: 10, style: (:bold if i.zero?)
    end
  end

  def line_item
    top = 324
    height = 19
    @pdf.fill_color "AAAAAA"
    @pdf.fill_rectangle [COLS.first, PAGE_H - top], COLS.last - COLS.first, height
    @pdf.fill_color "000000"
    @pdf.stroke_color "000000"
    @pdf.line_width 0.75
    COLS.each_cons(2) do |a, b|
      @pdf.stroke_rectangle [a, PAGE_H - top], b - a, height
    end
    %w[ITEM HOURS QUANTITY RATE AMOUNT].each_with_index do |h, i|
      text h, COLS[i], top + 5, size: 10, style: :bold, width: COLS[i + 1] - COLS[i], align: :center
    end

    y = 361
    text "Consultancy Service", COLS[0], y, size: 10
    text @invoice.period_label, COLS[0], y + 13, size: 8, width: COLS[1] - COLS[0] unless @invoice.full_month?
    text num(@invoice.hours), COLS[1] + 15, y, size: 10
    text "1", COLS[2], y, size: 10, width: 58, align: :right
    text money(@invoice.rate), COLS[3], y, size: 10, width: COLS[4] - COLS[3], align: :center
    text money(@invoice.amount), COLS[4], y, size: 10, width: COLS[5] - COLS[4], align: :center
  end

  def totals
    [["Subtotal:", money(@invoice.amount), 430],
     ["Tax (0%):", "#{@invoice.currency} 0.00", 447],
     ["Total:", money(@invoice.amount), 464]].each do |label, value, y|
      text label, 330, y, size: 10
      text value, 457, y, size: 10
    end
  end

  def bank_details
    text "Bank Details:", LEFT, 499, size: 10
    [["Bank Account Name:", @user.bank_account_name, 533],
     ["Account Number:", @user.bank_account_number, 550],
     ["Bank Name :", @user.bank_name, 567],
     ["SWIFT:", @user.bank_swift, 584]].each do |label, value, y|
      text "#{label} <b>#{escape(value)}</b>", LEFT, y, size: 10.5, inline: true, width: 470
    end
    text "Payment Method: Bank Transfer", LEFT, 601, size: 10.5
  end

  def text(str, x, y_top, size: 10, style: nil, width: 400, align: :left, inline: false)
    @pdf.font "Helvetica", style: style || :normal
    @pdf.text_box str.to_s, at: [x, PAGE_H - y_top], width: width, size: size, align: align,
                            inline_format: inline, overflow: :shrink_to_fit
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
