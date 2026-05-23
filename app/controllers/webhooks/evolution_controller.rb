# FORK:BEGIN — Inbound webhook receiver for Evolution-API (Baileys) WhatsApp instances.
class Webhooks::EvolutionController < ActionController::API
  def process_payload
    channel = Channel::Whatsapp.where(provider: 'evolution')
                               .find_by("provider_config->>'instance_name' = ?", params[:instance_name])

    return head :not_found if channel.blank?
    return head :unauthorized unless valid_apikey?(channel)

    handle_event(channel)
    head :ok
  rescue StandardError => e
    Rails.logger.error("[EVOLUTION] webhook error channel=#{channel&.id} event=#{params[:event]}: #{e.message}")
    head :ok
  end

  private

  def valid_apikey?(channel)
    presented = request.headers['apikey'].to_s
    expected_instance_key = channel.provider_config['evolution_instance_apikey'].to_s
    global_key = ENV.fetch('EVOLUTION_API_KEY', '').to_s

    return true if presented.present? && expected_instance_key.present? && ActiveSupport::SecurityUtils.secure_compare(presented, expected_instance_key)
    return true if presented.present? && global_key.present? && ActiveSupport::SecurityUtils.secure_compare(presented, global_key)

    false
  end

  def handle_event(channel)
    payload = params.to_unsafe_hash
    case payload[:event] || payload['event']
    when 'messages.upsert'
      Whatsapp::IncomingMessageEvolutionService.new(inbox: channel.inbox, params: payload).perform
    when 'connection.update'
      handle_connection_update(channel, payload)
    end
  end

  def handle_connection_update(channel, payload)
    state = payload.dig(:data, :state) || payload.dig('data', 'state')
    return if state.blank?

    previous = channel.provider_config['connection_state']
    channel.update!(provider_config: channel.provider_config.merge('connection_state' => state))

    channel.prompt_reauthorization! if previous == 'open' && state == 'close'
  end
end
# FORK:END
