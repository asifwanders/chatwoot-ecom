# ScheduledMessage
#
# Stores agent-composed or automation-composed messages queued for future delivery.
# Primary delivery path: ScheduledMessageJob (Sidekiq, wait_until: send_at).
# Belt-and-suspenders: ScheduledMessagesSweeperJob (sidekiq-cron, every minute)
# picks up rows whose Sidekiq scheduled entry was lost (restarts, redis flush).
#
# FORK NOTE: Fork-only. Upstream Chatwoot has no scheduled-message concept.
# If upstream adds one, migrate to it and delete this file.
class ScheduledMessage < ApplicationRecord
  STATUSES = %w[pending sent cancelled failed].freeze

  belongs_to :account
  belongs_to :conversation
  belongs_to :sender, polymorphic: true, optional: true
  belongs_to :sent_message, class_name: 'Message', optional: true

  validates :content, presence: true, unless: -> { content_attributes['attachments'].present? }
  validates :send_at, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :send_at_in_future, on: :create

  scope :pending, -> { where(status: 'pending') }
  scope :due, -> { pending.where('send_at <= ?', Time.current) }

  def cancel!(reason = nil)
    update!(status: 'cancelled', cancel_reason: reason)
  end

  def pending?
    status == 'pending'
  end

  private

  def send_at_in_future
    return if send_at.blank?

    errors.add(:send_at, 'must be in the future') if send_at <= Time.current
  end
end
