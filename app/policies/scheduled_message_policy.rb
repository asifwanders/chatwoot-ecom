# ScheduledMessagePolicy
#
# Re-uses conversation-level access: any agent who can view a conversation
# can schedule/list/cancel messages on it.
#
# FORK NOTE: Fork-only.
class ScheduledMessagePolicy < ApplicationPolicy
  def index?
    ConversationPolicy.new(@user_context, record.conversation).show?
  end

  def create?
    ConversationPolicy.new(@user_context, record.conversation).show?
  end

  def destroy?
    create?
  end
end
