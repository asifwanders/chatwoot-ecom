# ScheduledMessages::CreateService
#
# Persists a ScheduledMessage and enqueues its delivery job at `send_at`.
# Used by the composer API and by the `schedule_message` automation action.
#
# FORK NOTE: Fork-only.
class ScheduledMessages::CreateService
  def initialize(account:, conversation:, sender: nil, content:, send_at:, content_attributes: {}, message_type: 'outgoing')
    @account = account
    @conversation = conversation
    @sender = sender
    @content = content
    @send_at = send_at
    @content_attributes = content_attributes || {}
    @message_type = message_type
  end

  def perform
    scheduled = ScheduledMessage.create!(
      account: @account,
      conversation: @conversation,
      sender: @sender,
      content: @content,
      send_at: @send_at,
      content_attributes: @content_attributes,
      message_type: @message_type,
      status: 'pending'
    )
    ScheduledMessageJob.set(wait_until: scheduled.send_at).perform_later(scheduled.id)
    Rails.logger.info(
      "[scheduled_message] created id=#{scheduled.id} send_at=#{scheduled.send_at.iso8601} " \
      "conversation_id=#{@conversation.id} account_id=#{@account.id}"
    )
    scheduled
  end
end
