class CreateConversationAssignmentHistories < ActiveRecord::Migration[7.1]
  def change
    create_table :conversation_assignment_histories do |t|
      t.references :conversation, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.bigint :assignee_id
      t.bigint :team_id
      t.bigint :changed_by_user_id
      t.string :source, null: false, default: 'manual'
      t.text :reason
      t.datetime :assigned_at, null: false

      t.timestamps
    end

    add_index :conversation_assignment_histories,
              [:conversation_id, :assigned_at],
              order: { assigned_at: :desc },
              name: 'idx_cah_on_conversation_assigned_at'
    add_index :conversation_assignment_histories, :assignee_id
    add_index :conversation_assignment_histories, :team_id
  end
end
