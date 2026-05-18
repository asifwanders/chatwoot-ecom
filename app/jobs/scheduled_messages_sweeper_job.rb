# ScheduledMessagesSweeperJob
#
# Runs every minute via sidekiq-cron (see config/schedule.yml). Picks up
# pending rows whose send_at has passed but whose primary ScheduledMessageJob
# entry is missing (e.g. lost across a Redis flush) and re-enqueues them.
# DeliverService remains idempotent on duplicate runs.
#
# FORK NOTE: Fork-only.
class ScheduledMessagesSweeperJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    ScheduledMessage.due.find_each do |scheduled|
      ScheduledMessageJob.perform_later(scheduled.id)
    end
  end
end
