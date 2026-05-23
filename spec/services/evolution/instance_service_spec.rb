# FORK:BEGIN — Evolution::InstanceService spec
require 'rails_helper'

describe Evolution::InstanceService do
  let(:channel) do
    create(:channel_whatsapp,
           provider: 'evolution',
           provider_config: {
             'instance_name' => 'inst_abc',
             'evolution_instance_apikey' => 'inst-key',
             'evolution_base_url' => 'http://evo.test'
           },
           validate_provider_config: false,
           sync_templates: false)
  end

  subject(:service) { described_class.new(channel) }

  before do
    stub_const('ENV', ENV.to_hash.merge('EVOLUTION_API_KEY' => 'global-key'))
  end

  describe '#create' do
    it 'POSTs to /instance/create with Baileys integration' do
      stub_request(:post, 'http://evo.test/instance/create')
        .with(body: { instanceName: 'inst_abc', qrcode: true, integration: 'WHATSAPP-BAILEYS' }.to_json)
        .to_return(status: 200, body: { instance: { instanceName: 'inst_abc' }, hash: { apikey: 'k' } }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      expect(service.create.dig('hash', 'apikey')).to eq('k')
    end
  end

  describe '#connection_state' do
    it 'returns the state string' do
      stub_request(:get, 'http://evo.test/instance/connectionState/inst_abc')
        .to_return(status: 200, body: { instance: { state: 'open' } }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      expect(service.connection_state).to eq('open')
    end
  end

  describe '#send_text' do
    it 'posts to sendText endpoint' do
      stub_request(:post, 'http://evo.test/message/sendText/inst_abc')
        .with(body: { number: '923001234567', text: 'hi' }.to_json)
        .to_return(status: 200, body: { key: { id: 'M1' } }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      expect(service.send_text(to: '923001234567', text: 'hi').dig('key', 'id')).to eq('M1')
    end
  end

  describe 'error handling' do
    it 'raises Evolution::ApiError on non-2xx' do
      stub_request(:get, 'http://evo.test/instance/connectionState/inst_abc')
        .to_return(status: 500, body: 'boom')

      expect { service.connection_state }.to raise_error(Evolution::ApiError)
    end
  end
end
# FORK:END
