class Current < ActiveSupport::CurrentAttributes
  attribute :session, :admin_session
  delegate :user, to: :session, allow_nil: true
  delegate :administrator, to: :admin_session, allow_nil: true
end
