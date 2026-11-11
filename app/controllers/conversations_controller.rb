# The assistant page: the user's past conversations beside the open one (or a new, empty chat).
class ConversationsController < ApplicationController
  before_action :set_conversations
  before_action :set_conversation, only: %i[show destroy]

  def index
    @conversation = Current.user.conversations.new
    render :show
  end

  def show; end

  # Starts a conversation with its first message and the assistant's reply.
  def create
    text = message_text
    return redirect_to conversations_path, alert: "Type a message first." if text.blank?

    conversation = Current.user.conversations.create!
    begin
      TimelogAgent.new(conversation).reply(text)
      redirect_to conversation
    rescue TimelogAgent::Error => e
      redirect_to conversation, alert: e.message
    end
  end

  def destroy
    @conversation.destroy
    redirect_to conversations_path, notice: "Conversation deleted.", status: :see_other
  end

  private

  def set_conversations
    @conversations = Current.user.conversations.recent.limit(50)
  end

  def set_conversation
    @conversation = Current.user.conversations.find(params[:id])
  end

  def message_text = params[:message].to_s.strip.first(4000)
end
