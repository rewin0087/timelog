# UI skins. The selected key lives in the Rails session, so it resets to DEFAULT after sign out.
class Theme
  Skin = Data.define(:key, :name, :swatch)

  ALL = [
    Skin.new("violet",   "Violet",   "linear-gradient(135deg,#6d5efc,#c04cf5)"),
    Skin.new("ocean",    "Ocean",    "linear-gradient(135deg,#0ea5e9,#14b8a6)"),
    Skin.new("sunset",   "Sunset",   "linear-gradient(135deg,#f97316,#ec4899)"),
    Skin.new("forest",   "Forest",   "linear-gradient(135deg,#16a34a,#84cc16)"),
    Skin.new("candy",    "Candy",    "linear-gradient(135deg,#f472b6,#a78bfa)"),
    Skin.new("midnight", "Midnight", "linear-gradient(135deg,#1e1b4b,#818cf8)"),
    Skin.new("rainbow",  "Rainbow",  "conic-gradient(#ef4444,#f59e0b,#eab308,#22c55e,#06b6d4,#6366f1,#a855f7,#ef4444)"),
    Skin.new("lemonade", "Lemonade", "linear-gradient(135deg,#facc15,#fb923c)"),
    Skin.new("ruby",     "Ruby",     "linear-gradient(135deg,#be123c,#f43f5e)"),
    Skin.new("slate",    "Slate",    "linear-gradient(135deg,#334155,#94a3b8)"),
    Skin.new("mocha",    "Mocha",    "linear-gradient(135deg,#78350f,#d4a373)"),
    Skin.new("neon",     "Neon",     "linear-gradient(135deg,#0f0a1e 30%,#ff2bd6 65%,#22d3ee)"),
    Skin.new("aurora",   "Aurora",   "linear-gradient(135deg,#052e2b 25%,#34d399 60%,#a78bfa)")
  ].freeze

  DEFAULT = "violet"

  def self.valid?(key) = ALL.any? { |skin| skin.key == key }
  def self.resolve(key) = valid?(key) ? key : DEFAULT
end
