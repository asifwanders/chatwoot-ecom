# FORK:BEGIN — Evolution channels controller spec
require 'rails_helper'

RSpec.describe '/api/v2/accounts/{account.id}/channels/whatsapp_evolution_channels', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  before do
    stub_const('ENV', ENV.to_hash.merge('EVOLUTION_API_URL' => 'http://evo.test', 'FRONTEND_URL' => 'https://app.test'))
  end

  describe 'POST /create' do
    let(:params) do
      { whatsapp_evolution_channel: { name: 'WA Evo', phone_number: "+1555#{rand(1000..9999)}" } }
    end

    before do
      stub_request(:post, %r{http://evo.test/instance/create})
        .to_return(status: 200, body: { instance: { instanceName: 'x' }, hash: { apikey: 'instkey' } }.to_json,
                   headers: { 'Content-Type' => 'application/json' })
      stub_request(:post, %r{http://evo.test/webhook/set/.*})
        .to_return(status: 200, body: {}.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'is rejected when unauthenticated' do
      post "/api/v2/accounts/#{account.id}/channels/whatsapp_evolution_channels", params: params
      expect(response).to have_http_status(:unauthorized)
    end

    it 'creates an inbox for admins' do
      post "/api/v2/accounts/#{account.id}/channels/whatsapp_evolution_channels",
           params: params, headers: admin.create_new_auth_token

      expect(response).to have_http_status(:success)
      json = response.parsed_body
      expect(json['name']).to eq('WA Evo')
      channel = Channel::Whatsapp.last
      expect(channel.provider).to eq('evolution')
      expect(channel.provider_config['evolution_instance_apikey']).to eq('instkey')
    end

    it 'forbids agents' do
      post "/api/v2/accounts/#{account.id}/channels/whatsapp_evolution_channels",
           params: params, headers: agent.create_new_auth_token
      expect(response).to have_http_status(:unauthorized).or have_http_status(:forbidden)
    end
  end

  describe 'member endpoints' do
    let(:channel) do
      create(:channel_whatsapp, account: account, provider: 'evolution',
                                provider_config: { 'instance_name' => 'inst_abc',
                                                   'evolution_base_url' => 'http://evo.test',
                                                   'connection_state' => 'connecting' },
                                validate_provider_config: false, sync_templates: false)
    end
    let(:inbox) { channel.inbox }

    it 'GET qr returns code' do
      stub_request(:get, 'http://evo.test/instance/connect/inst_abc')
        .to_return(status: 200, body: { base64: 'B64', code: 'C', pairingCode: 'P' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      get "/api/v2/accounts/#{account.id}/channels/whatsapp_evolution_channels/#{inbox.id}/qr",
          headers: admin.create_new_auth_token
      expect(response).to have_http_status(:success)
      expect(response.parsed_body['base64']).to eq('B64')
    end

    it 'GET status updates connection_state' do
      stub_request(:get, 'http://evo.test/instance/connectionState/inst_abc')
        .to_return(status: 200, body: { instance: { state: 'open' } }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      get "/api/v2/accounts/#{account.id}/channels/whatsapp_evolution_channels/#{inbox.id}/status",
          headers: admin.create_new_auth_token
      expect(response.parsed_body['state']).to eq('open')
      expect(channel.reload.provider_config['connection_state']).to eq('open')
    end

    it 'POST disconnect calls logout and updates state' do
      stub_request(:delete, 'http://evo.test/instance/logout/inst_abc')
        .to_return(status: 200, body: {}.to_json, headers: { 'Content-Type' => 'application/json' })

      post "/api/v2/accounts/#{account.id}/channels/whatsapp_evolution_channels/#{inbox.id}/disconnect",
           headers: admin.create_new_auth_token
      expect(response).to have_http_status(:ok)
      expect(channel.reload.provider_config['connection_state']).to eq('close')
    end
  end
end
# FORK:END
