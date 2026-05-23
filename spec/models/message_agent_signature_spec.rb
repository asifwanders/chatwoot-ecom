require 'rails_helper'

RSpec.describe 'Message agent signature prepender', type: :model do
  let(:account) { create(:account) }
  let(:inbox)   { create(:inbox, account: account) }
  let(:agent)   { create(:user, account: account) }
  let(:team)    { create(:team, account: account, name: 'Sales') }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }
  let(:conversation) do
    create(:conversation, account: account, inbox: inbox, contact: contact,
                          contact_inbox: contact_inbox, assignee: agent, team: team)
  end

  def build_msg(content: 'hello', message_type: :outgoing, private: false, sender: agent)
    Message.create!(account: account, inbox: inbox, conversation: conversation,
                    content: content, message_type: message_type, private: private,
                    sender: sender)
  end

  context 'when prepend_agent_signature is enabled' do
    before { account.update!(settings: account.settings.merge('prepend_agent_signature' => true)) }

    it 'prepends agent + team for outgoing user message' do
      msg = build_msg(content: 'How can I help?')
      expect(msg.content).to start_with("#{agent.available_name} - Sales\n\n")
    end

    it 'omits team when conversation has no team' do
      conversation.update!(team: nil)
      msg = build_msg(content: 'No team here')
      expect(msg.content).to eq("#{agent.available_name}\n\nNo team here")
    end

    it 'does not double-prepend on idempotent re-save' do
      msg = build_msg(content: 'Hi')
      original = msg.content
      msg.save!
      expect(msg.reload.content).to eq(original)
    end

    it 'skips private notes' do
      msg = build_msg(content: 'internal', private: true)
      expect(msg.content).to eq('internal')
    end

    it 'skips incoming messages' do
      msg = Message.create!(account: account, inbox: inbox, conversation: conversation,
                            content: 'cust msg', message_type: :incoming, sender: contact)
      expect(msg.content).to eq('cust msg')
    end

    it 'skips non-User senders' do
      bot = create(:agent_bot, account: account)
      msg = Message.create!(account: account, inbox: inbox, conversation: conversation,
                            content: 'bot msg', message_type: :outgoing, sender: bot)
      expect(msg.content).to eq('bot msg')
    end
  end

  context 'when prepend_agent_signature is disabled (default)' do
    it 'leaves content unchanged' do
      msg = build_msg(content: 'plain')
      expect(msg.content).to eq('plain')
    end
  end
end
