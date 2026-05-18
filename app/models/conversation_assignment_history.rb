# ConversationAssignmentHistory
#
# Append-only log of assignee/team transitions on a conversation. Powers the
# `assign_previous_agent` / `assign_previous_team` automation actions which
# walk this history newest-first to pick a prior owner.
#
# Rows are written by ConversationAssignmentHistoryListener on every
# `conversation_updated` event where assignee_id or team_id actually changed.
#
# FORK NOTE: Fork-only. Upstream Chatwoot has no assignment-history table.
# If upstream adds one, migrate to it and delete this file + listener + migration.
class ConversationAssignmentHistory < ApplicationRecord
  SOURCES = %w[manual automation api round_robin].freeze

  belongs_to :conversation
  belongs_to :account
  belongs_to :assignee, class_name: 'User', optional: true
  belongs_to :team, optional: true
  belongs_to :changed_by_user, class_name: 'User', optional: true

  validates :source, inclusion: { in: SOURCES }
  validates :assigned_at, presence: true

  scope :for_conversation, ->(c) { where(conversation_id: c.id).order(assigned_at: :desc) }
end
