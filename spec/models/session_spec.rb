require "rails_helper"

RSpec.describe Session do
  let(:user) { create(:user, auto_lock_minutes: 5) }
  let(:session) { create(:session, user:) }

  describe "#locked?" do
    it "is unlocked while active" do
      expect(session.locked?).to be(false)
    end

    it "is locked after #lock!" do
      session.lock!
      expect(session.reload.locked?).to be(true)
    end

    it "locks itself after the user's idle period" do
      session.update!(last_active_at: 6.minutes.ago)
      expect(session.locked?).to be(true)
    end

    it "stays unlocked just inside the idle period" do
      session.update!(last_active_at: 4.minutes.ago)
      expect(session.locked?).to be(false)
    end

    it "never auto-locks when auto-lock is off" do
      user.update!(auto_lock_minutes: 0)
      session.update!(last_active_at: 2.days.ago)
      expect(session.locked?).to be(false)
    end
  end

  describe "#lock!" do
    it "keeps the original lock time" do
      session.lock!
      first = session.locked_at
      travel 1.minute
      session.lock!
      expect(session.reload.locked_at).to eq(first)
    end
  end

  describe "#unlock!" do
    it "clears the lock, refreshes activity, and resets failed attempts" do
      session.update!(locked_at: 1.hour.ago, last_active_at: 1.hour.ago, failed_unlock_attempts: 3)
      session.unlock!
      expect(session.reload).to have_attributes(locked_at: nil, failed_unlock_attempts: 0)
      expect(session.last_active_at).to be_within(1.second).of(Time.current)
    end
  end

  describe "#touch_activity!" do
    it "updates activity at most every 15 seconds" do
      session.update!(last_active_at: 10.seconds.ago)
      expect { session.touch_activity! }.not_to change { session.reload.last_active_at }

      session.update!(last_active_at: 20.seconds.ago)
      session.touch_activity!
      expect(session.reload.last_active_at).to be_within(1.second).of(Time.current)
    end

    it "sets activity when there is none yet" do
      session.update!(last_active_at: nil)
      session.touch_activity!
      expect(session.reload.last_active_at).to be_present
    end
  end

  describe "#record_failed_unlock!" do
    it "counts attempts and reports when the limit is reached" do
      results = Array.new(Session::MAX_UNLOCK_ATTEMPTS) { session.record_failed_unlock! }
      expect(results).to eq([ false, false, false, false, true ])
      expect(session.unlock_attempts_left).to eq(0)
    end
  end
end
