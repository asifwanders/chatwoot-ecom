# FORK:BEGIN — Periodic health check for Evolution-API channels.
# Polls each Evolution-backed WhatsApp instance for its connection state, updates
# provider_config['connection_state'], and prompts re-auth when transitioning open -> close.
module Evolution
  class HealthCheckJob < ApplicationJob
    queue_as :scheduled_jobs

    def perform
      Channel::Whatsapp.where(provider: 'evolution').find_each do |channel|
        check(channel)
      rescue StandardError => e
        Rails.logger.error("[EVOLUTION] health check failed channel=#{channel.id}: #{e.message}")
      end
    end

    private

    def check(channel)
      previous = channel.provider_config['connection_state']
      current = Evolution::InstanceService.new(channel).connection_state
      return if current.blank? || previous == current

      channel.update!(provider_config: channel.provider_config.merge('connection_state' => current))

      channel.prompt_reauthorization! if previous == 'open' && current == 'close'
    end
  end
end
# FORK:END
