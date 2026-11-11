# Sends a message in an existing conversation and streams back the saved exchange.
class ChatMessagesController < ApplicationController
  def create
    @conversation = Current.user.conversations.find(params[:conversation_id])
    text = params[:message].to_s.strip.first(4000)
    return head :unprocessable_content if text.blank?

    begin
      @reply = TimelogAgent.new(@conversation).reply(text)
    rescue TimelogAgent::Error => e
      @error = e.message
    end
    @user_message = @conversation.messages.where(role: "user").last
    @conversations = Current.user.conversations.recent.limit(50)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @conversation, alert: @error }
    end
  end
end
