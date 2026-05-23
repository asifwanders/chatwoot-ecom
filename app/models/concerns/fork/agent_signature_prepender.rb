# Fork::AgentSignaturePrepender
#
# Mixed into Message via config/initializers/fork_agent_signature.rb.
# Mutates `content` on create when account opts in via
# `account.settings['prepend_agent_signature']`.
#
# Skip:
#   - private notes, activity messages, auto-reply emails
#   - non-User senders (campaigns, bots, AutomationRule send_message etc.)
#   - blank content (attachment-only)
#   - content already starting with the computed prefix (retry/edit idempotency)
#
# FORK NOTE: Fork-only. Wired via `include` in an initializer so the
# upstream Message model file is untouched.
module Fork
  module AgentSignaturePrepender
    extend ActiveSupport::Concern

    included do
      before_validation :fork_prepend_agent_signature, on: :create
    end

    private

    def fork_prepend_agent_signature
      return unless account&.settings&.dig('prepend_agent_signature')
      return unless outgoing?
      return if private
      return if activity?
      return unless sender.is_a?(User)
      return if auto_reply_email?
      return if content.blank?

      prefix = fork_build_prefix
      return if prefix.blank?
      return if content.start_with?(prefix)

      self.content = "#{prefix}\n\n#{content}"
    end

    def fork_build_prefix
      agent_name = sender.available_name.presence || sender.name
      return nil if agent_name.blank?

      team_name = conversation&.team&.name
      team_name.present? ? "#{agent_name} - #{team_name}" : agent_name.to_s
    end
  end
end
