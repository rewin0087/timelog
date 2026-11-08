# Look of a generated PDF: a design (layout) and an accent colour used for header and table-header backgrounds.
# Defaults keep the original look: Classic, peach (FBE3D6) for timesheets and grey (AAAAAA) for invoices.
class PdfStyle
  DESIGNS = {
    "classic" => "Classic: boxed template with shaded headers",
    "modern" => "Modern: full-width colour header, striped rows",
    "minimal" => "Minimal: clean lines, colour accents only"
  }.freeze
  DEFAULT_COLORS = { report: "FBE3D6", invoice: "AAAAAA" }.freeze
  PRESETS = {
    "Peach" => "FBE3D6", "Silver" => "AAAAAA", "Sky" => "CFE8FC", "Mint" => "D3F5E4", "Lavender" => "E4DCFF",
    "Lemon" => "FFF1B8", "Indigo" => "4F46E5", "Teal" => "0F766E", "Crimson" => "B91C1C", "Charcoal" => "1F2937"
  }.freeze
  HEX = /\A#?(\h{6})\z/

  attr_reader :kind, :design, :color

  # The style for a PDF from request params, falling back to the user's account defaults.
  def self.from(kind, params, user)
    new(kind, design: [ params[:design], user.public_send("#{kind}_design") ], color: [ params[:color], user.public_send("#{kind}_color") ])
  end

  def self.design_label(key) = DESIGNS.fetch(key).split(":").first
  def self.normalize_color(value) = value.to_s.strip.match(HEX)&.[](1)&.upcase
  def self.valid_design?(value) = DESIGNS.key?(value.to_s)

  # The first valid design/colour wins, e.g. PdfStyle.new(:invoice, design: [params[:design], user.invoice_design]).
  def initialize(kind, design: nil, color: nil)
    @kind = kind
    @design = Array(design).map(&:to_s).find { |d| self.class.valid_design?(d) } || "classic"
    @color = Array(color).filter_map { |c| self.class.normalize_color(c) }.first || DEFAULT_COLORS.fetch(kind)
  end

  def default_color? = color == DEFAULT_COLORS.fetch(kind)
  def classic? = design == "classic"
  def modern? = design == "modern"
  def minimal? = design == "minimal"

  # Readable text on the accent background.
  def text_color = dark? ? "FFFFFF" : "000000"
  # A pale version for striped rows and soft fills.
  def tint = mix("FFFFFF", dark? ? 0.86 : 0.55)
  # A deep version for lines and coloured text on white (pale accents are too faint on their own).
  def strong = luminance > 0.55 ? mix("000000", 0.55) : color

  def dark? = luminance < 0.5

  private
    def rgb(hex = color) = hex.scan(/../).map { |c| c.to_i(16) }

    def luminance
      r, g, b = rgb.map { |c| c / 255.0 }
      0.2126 * r + 0.7152 * g + 0.0722 * b
    end

    def mix(other, amount)
      rgb.zip(rgb(other)).map { |a, b| (a + (b - a) * amount).round.clamp(0, 255) }.map { |c| format("%02X", c) }.join
    end
end
