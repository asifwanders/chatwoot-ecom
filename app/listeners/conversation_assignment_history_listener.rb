# ConversationAssignmentHistoryListener
#
# Subscribes to `conversation_updated` and appends a row to
# ConversationAssignmentHistory whenever assignee_id or team_id actually
# changed. Tags row source as 'automation' when an AutomationRule executed
# the change (detected via Current.executed_by, already set by
# AutomationRules::ActionService).
#
# FORK NOTE: Fork-only. Wired in AsyncDispatcher#listeners.
class ConversationAssignmentHistoryListener < BaseListener
  def conversation_created(event)
    conversation, account = extract_conversation_and_account(event)
    # Capture the initial assignee/team so `assign_previous_agent` can return
    # to the original CSR even when the only prior handoff is the very first
    # assignment at conversation create time.
    return if conversation.assignee_id.blank? && conversation.team_id.blank?

    write_row(conversation, account, event.data[:performed_by])
  end

  def conversation_updated(event)
    conversation, account = extract_conversation_and_account(event)
    changed = event.data[:changed_attributes] || {}

    assignee_changed = changed.key?('assignee_id') || changed.key?(:assignee_id)
    team_changed = changed.key?('team_id') || changed.key?(:team_id)
    return unless assignee_changed || team_changed

    write_row(conversation, account, event.data[:performed_by])
  end

  private

  def write_row(conversation, account, performed_by)
    source = if performed_by.is_a?(AutomationRule) || Current.executed_by.is_a?(AutomationRule)
               'automation'
             elsif performed_by.is_a?(User)
               'manual'
             else
               'api'
             end

    ConversationAssignmentHistory.create!(
      conversation_id: conversation.id,
      account_id: account.id,
      assignee_id: conversation.assignee_id,
      team_id: conversation.team_id,
      changed_by_user_id: performed_by.is_a?(User) ? performed_by.id : nil,
      source: source,
      assigned_at: Time.current
    )
  end
end
