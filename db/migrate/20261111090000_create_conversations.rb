class CreateConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :conversations do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false, default: "New chat"
      t.timestamps
    end
    add_index :conversations, %i[user_id updated_at]

    # One row per message in the OpenAI-style chat log the assistant replays as history:
    # user and assistant text, the assistant's tool calls, and each tool's JSON result.
    create_table :chat_messages do |t|
      t.references :conversation, null: false, foreign_key: { on_delete: :cascade }
      t.string :role, null: false
      t.text :content
      t.jsonb :tool_calls
      t.string :tool_call_id
      t.jsonb :suggestions, null: false, default: []
      t.timestamps
    end
  end
end
