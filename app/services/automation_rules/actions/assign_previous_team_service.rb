# AutomationRules::Actions::AssignPreviousTeamService
#
# Walks ConversationAssignmentHistory newest-first to find the most recent
# distinct prior team_id (other than current). Applies fallback when none.
#
# FORK NOTE: Fork-only.
class AutomationRules::Actions::AssignPreviousTeamService
  FALLBACKS = %w[leave_current leave_unassigned].freeze

  def initialize(rule:, conversation:, params:)
    @rule = rule
    @conversation = conversation
    @params = params || {}
  end

  def perform
    prior_team_id = @conversation.conversation_assignment_histories
                                 .where.not(team_id: nil)
                                 .order(assigned_at: :desc)
                                 .pluck(:team_id)
                                 .uniq
                                 .find { |t| t != @conversation.team_id }

    if prior_team_id
      Rails.logger.info(
        "[assign_previous_team] picked team_id=#{prior_team_id} " \
        "conversation_id=#{@conversation.id} account_id=#{@conversation.account_id}"
      )
      @conversation.update!(team_id: prior_team_id)
    else
      apply_fallback
    end
  end

  private

  def apply_fallback
    fallback = @params['fallback'].presence || 'leave_current'
    Rails.logger.warn(
      "[assign_previous_team] no eligible prior team; fallback=#{fallback} " \
      "conversation_id=#{@conversation.id} account_id=#{@conversation.account_id}"
    )
    @conversation.update!(team_id: nil) if fallback == 'leave_unassigned'
  end
end
