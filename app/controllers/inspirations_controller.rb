# Daily Bible verse + trivia, lazy-loaded into a Turbo Frame on the dashboard and the lock screen.
# The content is the same for everyone and holds no personal data, so it is served while locked.
class InspirationsController < ApplicationController
  skip_screen_lock only: :show

  def show
    @inspiration = DailyInspiration.for(Date.current)
    @compact = params[:compact].present?
    render layout: false
  end
end
