# Holidays and leave have no field of their own: they are ordinary todos, and the wording decides the kind.
# Kinds are checked in order, so "Unpaid sick leave" is unpaid (not paid leave), "Special non-working holiday"
# is non-working (not a plain holiday), and "Paid holiday" is paid leave.
#
#   billable: true  - the day counts as a full working day: its todos share the day's hours, and it is billed
#   billable: false - the day is logged (not "missed") but its todos get 0 hours and it is never billed
class DayKind
  Kind = Data.define(:key, :label, :pattern, :billable, :tone)

  ALL = [
    Kind.new(:unpaid, "Unpaid / absent",
             /\b(absent|unpaid\s+(sick\s+leave|vacation(\s+leave)?|holiday|leave))\b/i, false, "s5"),
    Kind.new(:public, "Public holiday", /\b(public|regular|national)\s+holiday/i, true, "s1"),
    Kind.new(:non_working, "Non-working holiday", /non[\s-]?working/i, true, "s2"),
    Kind.new(:paid_leave, "Paid leave",
             /\b(paid\s+(holiday|leave|vacation(\s+leave)?|sick\s+leave)|on\s+vacation|vacation\s+leave|sick\s+leave)\b/i, true, "s4"),
    Kind.new(:holiday, "Holiday", /holiday/i, true, "s3")
  ].freeze

  BY_KEY = ALL.index_by(&:key).freeze
  # Order for charts and tables: holidays, then paid leave, then unpaid.
  DISPLAY = %i[public non_working holiday paid_leave unpaid].map { |key| BY_KEY.fetch(key) }.freeze

  # Example wording shown in forms.
  PAID_EXAMPLES = [ "Paid holiday", "On vacation", "Sick leave", "Paid sick leave", "Paid vacation leave" ].freeze
  UNPAID_EXAMPLES = [ "Absent", "Unpaid sick leave", "Unpaid vacation leave", "Unpaid holiday" ].freeze

  def self.for(todo) = ALL.find { |kind| todo.to_s.match?(kind.pattern) }
  def self.[](key) = BY_KEY.fetch(key)
  def self.billable?(todo) = self.for(todo)&.billable != false

  # Dates where every todo is unbillable (an unpaid day), from [date, todo] pairs.
  def self.unpaid_dates(rows)
    rows.group_by(&:first).filter_map { |date, day| date if day.none? { |_, todo| billable?(todo) } }
  end
end
