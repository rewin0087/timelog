Prawn::Fonts::AFM.hide_m17n_warning = true

module PdfHelpers
  def pdf_text(binary) = PDF::Inspector::Text.analyze(binary).strings.join(" ")
end

RSpec.configure { |config| config.include PdfHelpers }
