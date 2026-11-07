module ChartsHelper
  # Clean axis ticks from 0 up to the first step at or above `max` (e.g. 0/50/100/150/200).
  def chart_ticks(max, count: 4)
    max = max.to_f
    return [ 0, 1 ] unless max.positive?
    raw = max / count
    magnitude = 10**Math.log10(raw).floor
    step = [ 1, 2, 2.5, 5, 10 ].map { |m| m * magnitude }.find { |s| s >= raw }
    ticks = [ 0 ]
    ticks << ticks.last + step while ticks.last < max - 1e-9
    ticks.map { |t| t == t.to_i ? t.to_i : t.round(2) }
  end

  # Fixed series colour per holiday kind (tone-s1..s3), shared by every holiday chart.
  def holiday_tone(kind)
    "s#{TimeStats::HOLIDAY_KINDS.index { |k, _, _| k == kind } + 1}"
  end

  # Position of `value` on a 0..max scale, as a CSS percentage string.
  def chart_pct(value, max)
    return "0%" unless max.to_f.positive?
    "#{(value.to_f / max.to_f * 100).clamp(0, 100).round(2)}%"
  end

  # 160 -> "160h", 7.6190 -> "7.62h", 7.5 -> "7.5h".
  def fmt_hours(value, precision: 2)
    "#{number_with_precision(value, precision: precision, strip_insignificant_zeros: true, delimiter: ',')}h"
  end

  def fmt_money(currency, value)
    "#{currency} #{number_with_delimiter(number_with_precision(value, precision: 2))}"
  end

  # Amount hidden behind dots until revealed by the surrounding reveal controller (no per-item button).
  def masked_money(currency, value)
    tag.span(class: "masked", data: { reveal_target: "item" }) do
      tag.span(fmt_money(currency, value), class: "masked-value") +
        tag.span("#{currency} ••••••", class: "masked-dots", aria: { hidden: true })
    end
  end
end
