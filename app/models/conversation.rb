# A chat with the timelog assistant (TimelogAgent). Messages keep the full chat log, tool calls included,
# so reopening a conversation later carries on with everything that was said.
class Conversation < ApplicationRecord
  TITLE_LENGTH = 60

  belongs_to :user
  has_many :messages, -> { order(:id) }, class_name: "ChatMessage", inverse_of: :conversation, dependent: :delete_all

  scope :recent, -> { order(updated_at: :desc, id: :desc) }

  # Named after the first thing the user asked.
  def title_from(text)
    update!(title: text.to_s.squish.truncate(TITLE_LENGTH)) if messages.where(role: "user").none?
  end

  # What the user sees: their messages and the assistant's text replies (not tool calls or results).
  def visible_messages = messages.select(&:visible?)

  # Follow-up ideas from the latest assistant reply.
  def suggestions = messages.reverse.find(&:reply?)&.suggestions.to_a
end
