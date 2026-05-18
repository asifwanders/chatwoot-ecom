# AutomationRules::Actions::ScheduleMessageService
#
# Implements the `schedule_message` automation action. Reads
# `offset_seconds` and `content_template`, interpolates Liquid drops against
# the conversation's contact/conversation/account, and persists a
# ScheduledMessage via ScheduledMessages::CreateService.
#
# FORK NOTE: Fork-only. Action key registered in AutomationRule#actions_attributes.
class AutomationRules::Actions::ScheduleMessageService
  def initialize(rule:, conversation:, params:)
    @rule = rule
    @conversation = conversation
    @params = params || {}
  end

  def perform
    offset = @params['offset_seconds'].to_i
    template = @params['content_template'].to_s
    return if template.blank?

    rendered = render_template(template)
    ScheduledMessages::CreateService.new(
      account: @conversation.account,
      conversation: @conversation,
      sender: nil,
      content: rendered,
      send_at: Time.current + offset.seconds,
      content_attributes: { 'automation_rule_id' => @rule.id }
    ).perform
  end

  private

  def render_template(template)
    drops = {
      'contact' => ContactDrop.new(@conversation.contact),
      'conversation' => ConversationDrop.new(@conversation),
      'inbox' => InboxDrop.new(@conversation.inbox),
      'account' => AccountDrop.new(@conversation.account)
    }
    escaped = template.gsub(/`(.*?)`/m, '{% raw %}`\\1`{% endraw %}')
    Liquid::Template.parse(escaped).render(drops)
  rescue Liquid::Error
    template
  end
end
