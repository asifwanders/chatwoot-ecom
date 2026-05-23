# FORK:BEGIN — IncomingMessageEvolutionService spec
require 'rails_helper'

describe Whatsapp::IncomingMessageEvolutionService do
  let(:channel) do
    create(:channel_whatsapp,
           provider: 'evolution',
           provider_config: { 'instance_name' => 'inst_abc' },
           validate_provider_config: false,
           sync_templates: false)
  end
  let(:inbox) { channel.inbox }

  let(:base_payload) do
    {
      'event' => 'messages.upsert',
      'instance' => 'inst_abc',
      'data' => {
        'key' => { 'remoteJid' => '923001234567@s.whatsapp.net', 'fromMe' => false, 'id' => 'WA-1' },
        'pushName' => 'Alice',
        'message' => { 'conversation' => 'hello there' },
        'messageTimestamp' => 1_700_000_000,
        'messageType' => 'conversation'
      }
    }
  end

  it 'creates a contact, conversation, and incoming message' do
    expect { described_class.new(inbox: inbox, params: base_payload).perform }
      .to change(Contact, :count).by(1)
      .and change(Conversation, :count).by(1)
      .and change(Message, :count).by(1)

    msg = Message.find_by(source_id: 'WA-1')
    expect(msg.content).to eq('hello there')
    expect(msg.message_type).to eq('incoming')
    expect(msg.sender.name).to eq('Alice')
  end

  it 'is idempotent on duplicate source_id' do
    described_class.new(inbox: inbox, params: base_payload).perform
    expect { described_class.new(inbox: inbox, params: base_payload).perform }
      .not_to change(Message, :count)
  end

  it 'ignores fromMe messages' do
    payload = base_payload.deep_dup
    payload['data']['key']['fromMe'] = true
    expect { described_class.new(inbox: inbox, params: payload).perform }
      .not_to change(Message, :count)
  end

  it 'captures in_reply_to_external_id from extendedTextMessage context' do
    payload = base_payload.deep_dup
    payload['data']['message'] = {
      'extendedTextMessage' => {
        'text' => 'replying',
        'contextInfo' => { 'stanzaId' => 'PREV-1' }
      }
    }
    described_class.new(inbox: inbox, params: payload).perform
    msg = Message.find_by(source_id: 'WA-1')
    expect(msg.content_attributes['in_reply_to_external_id']).to eq('PREV-1')
  end
end
# FORK:END
