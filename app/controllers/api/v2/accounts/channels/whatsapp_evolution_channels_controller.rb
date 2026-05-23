# FORK:BEGIN — Management endpoints for Evolution-API WhatsApp channels.
class Api::V2::Accounts::Channels::WhatsappEvolutionChannelsController < Api::V1::Accounts::BaseController
  before_action :authorize_create, only: [:create]
  before_action :load_channel, only: [:qr, :status, :reconnect, :disconnect]
  before_action :authorize_update, only: [:qr, :status, :reconnect, :disconnect]

  def create
    instance_name = "cw_acct#{Current.account.id}_#{SecureRandom.hex(4)}"
    creation = Evolution::InstanceService.new(nil, instance_name: instance_name).create
    # Evolution v2 returns `hash` as a bare API-key string (older versions used a nested hash).
    raw_hash = creation['hash']
    instance_apikey = raw_hash.is_a?(Hash) ? raw_hash['apikey'] : raw_hash

    ActiveRecord::Base.transaction do
      @channel = Current.account.whatsapp_channels.create!(
        phone_number: permitted_params[:phone_number],
        provider: 'evolution',
        provider_config: {
          'instance_name' => instance_name,
          'evolution_instance_apikey' => instance_apikey,
          'evolution_base_url' => ENV.fetch('EVOLUTION_API_URL', Evolution::InstanceService::DEFAULT_BASE_URL),
          'connection_state' => 'connecting'
        }
      )
      @inbox = Current.account.inboxes.create!(
        name: permitted_params[:name],
        channel: @channel
      )
    end

    set_webhook(instance_name)

    render :create
  rescue Evolution::ApiError, ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def qr
    render json: Evolution::InstanceService.new(@channel).fetch_qr
  rescue Evolution::ApiError => e
    render json: { error: e.message }, status: :bad_gateway
  end

  def status
    state = Evolution::InstanceService.new(@channel).connection_state
    @channel.update!(provider_config: @channel.provider_config.merge('connection_state' => state)) if state.present?
    render json: { state: state }
  rescue Evolution::ApiError => e
    render json: { error: e.message }, status: :bad_gateway
  end

  def reconnect
    service = Evolution::InstanceService.new(@channel)
    service.restart
    render json: service.fetch_qr
  rescue Evolution::ApiError => e
    render json: { error: e.message }, status: :bad_gateway
  end

  def disconnect
    Evolution::InstanceService.new(@channel).logout
    @channel.update!(provider_config: @channel.provider_config.merge('connection_state' => 'close'))
    head :ok
  rescue Evolution::ApiError => e
    render json: { error: e.message }, status: :bad_gateway
  end

  private

  def permitted_params
    params.require(:whatsapp_evolution_channel).permit(:name, :phone_number)
  end

  def authorize_create
    authorize ::Inbox
  end

  def load_channel
    @inbox = Current.account.inboxes.find(params[:id])
    @channel = @inbox.channel
    raise ActiveRecord::RecordNotFound unless @channel.is_a?(Channel::Whatsapp) && @channel.provider == 'evolution'
  end

  def authorize_update
    authorize @inbox, :update?
  end

  def set_webhook(instance_name)
    # Prefer EVOLUTION_WEBHOOK_BASE_URL so Evolution can hit Rails directly on
    # the internal docker network (e.g. http://rails:3000). Public hostname via
    # Cloudflare often fails from inside the Evolution container.
    base = ENV.fetch('EVOLUTION_WEBHOOK_BASE_URL', '').presence ||
           ENV.fetch('FRONTEND_URL', '').presence
    return unless base

    webhook_url = "#{base.chomp('/')}/webhooks/evolution/#{instance_name}"
    Evolution::InstanceService.new(@channel).set_webhook(webhook_url)
  rescue Evolution::ApiError => e
    Rails.logger.error("[EVOLUTION] set_webhook failed: #{e.message}")
  end
end
# FORK:END
