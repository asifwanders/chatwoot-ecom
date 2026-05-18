class CreateScheduledMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :scheduled_messages do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :conversation, null: false, foreign_key: { on_delete: :cascade }
      t.bigint :sender_id
      t.bigint :sent_message_id
      t.string :sender_type
      t.text :content
      t.jsonb :content_attributes, null: false, default: {}
      t.string :message_type, null: false, default: 'outgoing'
      t.datetime :send_at, null: false
      t.string :status, null: false, default: 'pending'
      t.text :cancel_reason

      t.timestamps
    end

    add_index :scheduled_messages, [:status, :send_at]
    add_index :scheduled_messages, [:conversation_id, :status]
  end
end
