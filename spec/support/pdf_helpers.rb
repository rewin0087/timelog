Prawn::Fonts::AFM.hide_m17n_warning = true

module PdfHelpers
  def pdf_text(binary) = PDF::Inspector::Text.analyze(binary).strings.join(" ")

  # Hex colours (e.g. "FBE3D6") used for fills and strokes on every page.
  def pdf_colors(binary)
    PDF::Reader.new(StringIO.new(binary)).pages
               .flat_map { |page| page.raw_content.scan(/^([\d.]+) ([\d.]+) ([\d.]+) (?:scn|SCN)$/) }
               .map { |rgb| rgb.map { |v| format("%02X", (v.to_f * 255).round) }.join }.uniq
  end
end

RSpec.configure { |config| config.include PdfHelpers }
