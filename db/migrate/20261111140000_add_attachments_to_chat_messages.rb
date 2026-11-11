class AddAttachmentsToChatMessages < ActiveRecord::Migration[8.1]
  def change
    # Documents the assistant produced for a reply, shown as cards with preview/download buttons:
    # [{ "kind" => "invoice", "invoice_id" => 1 }, { "kind" => "report", "from" => "2026-11-01", "to" => "2026-11-30" }]
    add_column :chat_messages, :attachments, :jsonb, null: false, default: []
  end
end
