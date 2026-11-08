# Unpaid leave and absent todos now get 0 hours (see DayKind). Re-split every user's existing days so
# entries logged before this change follow the new rule. Invoices keep their hours until regenerated.
class RebalanceTimeEntriesForLeave < ActiveRecord::Migration[8.1]
  def up
    User.find_each(&:rebalance_time_entries!)
  end

  def down
    # Nothing to undo: hours are always derived from the todos and the user's hours rule.
  end
end
