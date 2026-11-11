# One entry in a Conversation's chat log, stored in the OpenAI chat format sent to FuelIX:
#   user      - content
#   assistant - content and/or tool_calls ([{ id, type: "function", function: { name, arguments } }])
#   tool      - content (the tool's JSON result) for tool_call_id
class ChatMessage < ApplicationRecord
  ROLES = %w[user assistant tool].freeze

  belongs_to :conversation, touch: true

  validates :role, inclusion: { in: ROLES }

  def user? = role == "user"
  def reply? = role == "assistant" && content.present?
  def visible? = user? || reply?

  # The message as the chat completions API expects it.
  def to_api
    case role
    when "tool" then { role:, tool_call_id:, content: content.to_s }
    when "assistant" then { role:, content: content.presence, tool_calls: tool_calls.presence }.compact
    else { role:, content: content.to_s }
    end
  end
end
