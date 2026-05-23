# FORK:BEGIN — WhatsappEvolutionService spec
require 'rails_helper'

describe Whatsapp::Providers::WhatsappEvolutionService do
  subject(:service) { described_class.new(whatsapp_channel: channel) }

  let(:channel) do
    create(:channel_whatsapp,
           provider: 'evolution',
           provider_config: {
             'instance_name' => 'inst_abc',
             'evolution_base_url' => 'http://evo.test'
           },
           validate_provider_config: false,
           sync_templates: false)
  end

  let(:conversation) { create(:conversation, inbox: channel.inbox) }
  let(:message) do
    create(:message, conversation: conversation, inbox: channel.inbox,
                     message_type: :outgoing, content: 'hello')
  end

  describe '#validate_provider_config?' do
    it 'requires instance_name' do
      expect(service.validate_provider_config?).to be(true)
    end
  end

  describe '#api_headers' do
    it { expect(service.api_headers).to eq({}) }
  end

  describe '#media_url' do
    it 'passes through' do
      expect(service.media_url('http://x/foo.jpg')).to eq('http://x/foo.jpg')
    end
  end

  describe '#send_template' do
    it 'raises NotImplementedError' do
      expect { service.send_template('923001234567', {}, message) }.to raise_error(NotImplementedError)
    end
  end

  describe '#send_message' do
    it 'sends text via Evolution and returns the message id' do
      stub_request(:post, 'http://evo.test/message/sendText/inst_abc')
        .to_return(status: 200, body: { key: { id: 'EVO-1' } }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      expect(service.send_message('+923001234567', message)).to eq('EVO-1')
    end

    it 'marks the message failed on Evolution error' do
      stub_request(:post, 'http://evo.test/message/sendText/inst_abc')
        .to_return(status: 500, body: 'fail')

      service.send_message('+923001234567', message)
      expect(message.reload.status).to eq('failed')
    end
  end
end
# FORK:END
