# FORK:BEGIN — Evolution::HealthCheckJob spec
require 'rails_helper'

describe Evolution::HealthCheckJob do
  let!(:channel) do
    create(:channel_whatsapp,
           provider: 'evolution',
           provider_config: {
             'instance_name' => 'inst_abc',
             'evolution_base_url' => 'http://evo.test',
             'connection_state' => 'open'
           },
           validate_provider_config: false,
           sync_templates: false)
  end

  it 'updates connection_state on change' do
    stub_request(:get, 'http://evo.test/instance/connectionState/inst_abc')
      .to_return(status: 200, body: { instance: { state: 'close' } }.to_json,
                 headers: { 'Content-Type' => 'application/json' })

    described_class.perform_now
    expect(channel.reload.provider_config['connection_state']).to eq('close')
  end

  it 'prompts reauthorization on open -> close transition' do
    stub_request(:get, 'http://evo.test/instance/connectionState/inst_abc')
      .to_return(status: 200, body: { instance: { state: 'close' } }.to_json,
                 headers: { 'Content-Type' => 'application/json' })

    expect_any_instance_of(Channel::Whatsapp).to receive(:prompt_reauthorization!)
    described_class.perform_now
  end

  it 'does not raise when one channel errors' do
    stub_request(:get, 'http://evo.test/instance/connectionState/inst_abc')
      .to_return(status: 500, body: 'boom')

    expect { described_class.perform_now }.not_to raise_error
  end
end
# FORK:END
