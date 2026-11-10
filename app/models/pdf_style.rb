# Look of a generated PDF: a design (layout) and an accent colour used for header and table-header backgrounds.
# Defaults keep the original look: Classic, peach (FBE3D6) for timesheets and grey (AAAAAA) for invoices.
class PdfStyle
  DESIGNS = {
    "classic" => "Classic: boxed template with shaded headers",
    "modern" => "Modern: full-width colour header, striped rows",
    "minimal" => "Minimal: clean lines, colour accents only",
    "elegant" => "Elegant: serif type, centred title, fine double rules",
    "bold" => "Bold: colour side band, oversized title",
    "executive" => "Executive: deep header band, accent stripe and footer",
    "aurora" => "Aurora: two-tone gradient header",
    "typewriter" => "Typewriter: monospaced type, dashed rules"
  }.freeze
  # Built-in PDF fonts (no embedding needed); designs not listed use Helvetica.
  FONTS = { "elegant" => "Times-Roman", "typewriter" => "Courier" }.freeze
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
  def font = FONTS.fetch(design, "Helvetica")

  # Readable text on the accent background.
  def text_color = dark? ? "FFFFFF" : "000000"
  # A pale version for striped rows and soft fills.
  def tint = mix("FFFFFF", dark? ? 0.86 : 0.55)
  # A deep version for lines and coloured text on white (pale accents are too faint on their own).
  def strong = luminance > 0.55 ? mix("000000", 0.55) : color

  # A dark version that always takes white text (header bands, footers).
  def deep = mix("000000", dark? ? 0.45 : 0.68)
  # Readable text on any background.
  def text_on(hex) = luminance(hex) < 0.5 ? "FFFFFF" : "000000"

  # The accent's companion for gradients: hue turned 40 degrees, nudged lighter/darker until it takes the same
  # text colour as the accent, so text stays readable across the whole gradient.
  def partner
    @partner ||= begin
      hex = rotate_hue(color, 40)
      target = text_color
      10.times { break if text_on(hex) == target; hex = mix("000000", target == "FFFFFF" ? 0.15 : -0.15, hex) }
      hex
    end
  end

  def dark? = luminance < 0.5

  private
    def rgb(hex = color) = hex.scan(/../).map { |c| c.to_i(16) }

    def luminance(hex = color)
      r, g, b = rgb(hex).map { |c| c / 255.0 }
      0.2126 * r + 0.7152 * g + 0.0722 * b
    end

    # Moves `base` towards `other` by `amount` (negative moves away, e.g. lighter when other is black).
    def mix(other, amount, base = color)
      rgb(base).zip(rgb(other)).map { |a, b| (a + (b - a) * amount).round.clamp(0, 255) }.map { |c| format("%02X", c) }.join
    end

    def rotate_hue(hex, degrees)
      r, g, b = rgb(hex).map { |c| c / 255.0 }
      max, min = [r, g, b].max, [r, g, b].min
      l = (max + min) / 2
      return hex if max == min # greys have no hue
      d = max - min
      s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
      h = case max
          when r then ((g - b) / d) % 6
          when g then (b - r) / d + 2
          else (r - g) / d + 4
          end * 60
      h = (h + degrees) % 360
      c = (1 - (2 * l - 1).abs) * s
      x = c * (1 - ((h / 60) % 2 - 1).abs)
      m = l - c / 2
      r1, g1, b1 = [[c, x, 0], [x, c, 0], [0, c, x], [0, x, c], [x, 0, c], [c, 0, x]][(h / 60).floor % 6]
      [r1, g1, b1].map { |v| format("%02X", ((v + m) * 255).round.clamp(0, 255)) }.join
    end
end
