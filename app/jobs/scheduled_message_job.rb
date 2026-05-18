# ScheduledMessageJob
#
# Per-row delivery job. Enqueued by ScheduledMessages::CreateService with
# `wait_until: send_at`. Idempotent: DeliverService aborts on non-pending rows,
# so duplicate enqueues from the sweeper are safe.
#
# FORK NOTE: Fork-only.
class ScheduledMessageJob < ApplicationJob
  queue_as :default

  def perform(scheduled_message_id)
    scheduled = ScheduledMessage.find_by(id: scheduled_message_id)
    return if scheduled.nil? || !scheduled.pending?

    ScheduledMessages::DeliverService.new(scheduled).perform
  end
end
