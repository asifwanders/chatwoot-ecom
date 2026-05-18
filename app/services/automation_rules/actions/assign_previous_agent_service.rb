# AutomationRules::Actions::AssignPreviousAgentService
#
# Walks ConversationAssignmentHistory newest-first and re-assigns the
# conversation to the most recent prior assignee that isn't the current one
# (or the current team's assignee). Skips offline agents; applies fallback
# strategy when no eligible prior agent is found.
#
# FORK NOTE: Fork-only. Wired via AutomationRules::ActionService dispatcher.
class AutomationRules::Actions::AssignPreviousAgentService
  FALLBACKS = %w[round_robin_previous_team leave_unassigned keep_current].freeze

  def initialize(rule:, conversation:, params:)
    @rule = rule
    @conversation = conversation
    @params = params || {}
    @account = conversation.account
  end

  def perform
    candidate = pick_previous_agent
    if candidate
      Rails.logger.info(
        "[assign_previous_agent] picked user_id=#{candidate.id} " \
        "conversation_id=#{@conversation.id} account_id=#{@account.id}"
      )
      @conversation.update!(assignee_id: candidate.id)
    else
      apply_fallback
    end
  end

  private

  def pick_previous_agent
    history = @conversation.conversation_assignment_histories.order(assigned_at: :desc)
    current_assignee_id = @conversation.assignee_id
    current_team_id = @conversation.team_id

    history.each do |row|
      next if row.assignee_id.blank?
      # Skip current owner — we want the assignee from *before* this handoff.
      next if row.assignee_id == current_assignee_id
      # Skip rows whose team matches current; those are part of the current handoff cycle.
      next if current_team_id.present? && row.team_id == current_team_id

      user = @account.users.find_by(id: row.assignee_id)
      next if user.nil?
      next unless agent_online?(user) && agent_belongs_to_inbox?(user)

      return user
    end
    nil
  end

  def apply_fallback
    fallback = @params['fallback'].presence || 'keep_current'
    Rails.logger.warn(
      "[assign_previous_agent] no eligible prior agent; fallback=#{fallback} " \
      "conversation_id=#{@conversation.id} account_id=#{@account.id}"
    )
    case fallback
    when 'leave_unassigned'
      @conversation.update!(assignee_id: nil)
    when 'round_robin_previous_team'
      round_robin_previous_team
    end
  end

  def round_robin_previous_team
    prior_team_id = @conversation.conversation_assignment_histories
                                 .where.not(team_id: nil)
                                 .order(assigned_at: :desc)
                                 .pluck(:team_id)
                                 .uniq
                                 .find { |t| t != @conversation.team_id }
    return if prior_team_id.blank?

    @conversation.update!(team_id: prior_team_id)
    allowed_ids = Team.find(prior_team_id).team_members.pluck(:user_id).map(&:to_s)
    user = AutoAssignment::InboxRoundRobinService.new(inbox: @conversation.inbox)
                                                  .available_agent(allowed_agent_ids: allowed_ids)
    @conversation.update!(assignee_id: user.id) if user
  end

  def agent_online?(user)
    account_user = @account.account_users.find_by(user_id: user.id)
    account_user&.online?
  end

  def agent_belongs_to_inbox?(user)
    @conversation.inbox.inbox_members.exists?(user_id: user.id) ||
      @account.administrators.exists?(id: user.id)
  end
end
