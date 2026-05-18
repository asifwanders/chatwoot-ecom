# ScheduledMessages::DeliverService
#
# Transitions a ScheduledMessage to `sent` by constructing a real Message via
# Messages::MessageBuilder. Idempotent: aborts if record is not pending. Will
# cancel itself (status=cancelled) when the conversation has resolved before
# delivery time — keeps stale follow-ups from being delivered after the
# customer issue is already closed.
#
# FORK NOTE: Fork-only. See ScheduledMessage docstring.
class ScheduledMessages::DeliverService
  # TODO: expose as account setting `cancel_scheduled_on_resolve` once we ship
  # a settings UI; for now hardcoded true.
  CANCEL_ON_RESOLVE = true

  def initialize(scheduled_message)
    @scheduled = scheduled_message
  end

  def perform
    return unless @scheduled.pending?

    conversation = @scheduled.conversation

    if CANCEL_ON_RESOLVE && conversation.resolved?
      @scheduled.update!(status: 'cancelled', cancel_reason: 'conversation_resolved')
      Rails.logger.info(
        "[scheduled_message] cancelled id=#{@scheduled.id} reason=resolved " \
        "conversation_id=#{conversation.id} account_id=#{@scheduled.account_id}"
      )
      return
    end

    message = build_message(conversation)
    @scheduled.update!(status: 'sent', sent_message_id: message.id)
    Rails.logger.info(
      "[scheduled_message] sent id=#{@scheduled.id} message_id=#{message.id} " \
      "conversation_id=#{conversation.id} account_id=#{@scheduled.account_id}"
    )
    message
  rescue StandardError => e
    @scheduled.update(status: 'failed', cancel_reason: e.message.to_s.truncate(500))
    Rails.logger.error(
      "[scheduled_message] failed id=#{@scheduled.id} error=#{e.class} " \
      "conversation_id=#{@scheduled.conversation_id} account_id=#{@scheduled.account_id}"
    )
    ChatwootExceptionTracker.new(e, account: @scheduled.account).capture_exception
  end

  private

  def build_message(conversation)
    user = @scheduled.sender if @scheduled.sender.is_a?(User)
    params = ActionController::Parameters.new(
      content: @scheduled.content,
      message_type: @scheduled.message_type,
      private: false,
      content_attributes: @scheduled.content_attributes.merge('scheduled_message_id' => @scheduled.id)
    )
    Messages::MessageBuilder.new(user, conversation, params).perform
  end
end
