# FORK:BEGIN — Evolution-API client wrapper (Baileys-based WhatsApp provider)
# Thin REST client around the Evolution API (https://doc.evolution-api.com).
# Used by Channel::Whatsapp records whose provider == 'evolution'.
module Evolution
  class ApiError < StandardError
    attr_reader :status, :body

    def initialize(status, body)
      @status = status
      @body = body
      super("Evolution API error #{status}: #{body}")
    end
  end

  class InstanceService
    DEFAULT_BASE_URL = 'http://evolution-api:8080'.freeze

    def initialize(channel = nil, instance_name: nil, api_key: nil, base_url: nil)
      @channel = channel
      @explicit_instance_name = instance_name
      @explicit_api_key = api_key
      @explicit_base_url = base_url
    end

    def instance_name
      @explicit_instance_name || @channel&.provider_config&.dig('instance_name')
    end

    def base_url
      @explicit_base_url ||
        @channel&.provider_config&.dig('evolution_base_url') ||
        ENV.fetch('EVOLUTION_API_URL', DEFAULT_BASE_URL)
    end

    def api_key
      @explicit_api_key || ENV.fetch('EVOLUTION_API_KEY', '')
    end

    def create
      post('/instance/create', {
             instanceName: instance_name,
             qrcode: true,
             integration: 'WHATSAPP-BAILEYS'
           })
    end

    def fetch_qr
      data = get("/instance/connect/#{instance_name}")
      {
        base64: data['base64'] || data.dig('qrcode', 'base64'),
        code: data['code'] || data.dig('qrcode', 'code'),
        pairing_code: data['pairingCode'] || data.dig('qrcode', 'pairingCode')
      }
    end

    def connection_state
      data = get("/instance/connectionState/#{instance_name}")
      data.dig('instance', 'state') || data['state']
    end

    def restart
      post("/instance/restart/#{instance_name}", {})
    end

    def logout
      delete("/instance/logout/#{instance_name}")
    end

    def delete_instance
      delete("/instance/delete/#{instance_name}")
    end

    def set_webhook(url, events: %w[MESSAGES_UPSERT CONNECTION_UPDATE])
      # Forward `apikey` header on every webhook call so the receiver can
      # authenticate. Use the per-instance key when available; fall back to
      # the global key.
      hdr_key = (@channel&.provider_config&.dig('evolution_instance_apikey').presence) ||
                ENV.fetch('EVOLUTION_API_KEY', '')
      post("/webhook/set/#{instance_name}", {
             webhook: {
               url: url,
               enabled: true,
               events: events,
               headers: { apikey: hdr_key }
             }
           })
    end

    def send_text(to:, text:, quoted: nil)
      body = { number: to, text: text }
      if quoted.present?
        body[:options] = {
          quoted: { key: { id: quoted[:id], remoteJid: quoted[:remoteJid] } }
        }
      end
      post("/message/sendText/#{instance_name}", body)
    end

    def send_media(to:, type:, url:, caption: nil, filename: nil)
      body = { number: to, mediatype: type, media: url }
      body[:caption] = caption if caption.present?
      body[:fileName] = filename if filename.present?
      post("/message/sendMedia/#{instance_name}", body)
    end

    private

    def post(path, body)
      response = HTTParty.post(
        "#{base_url}#{path}",
        headers: headers,
        body: body.to_json,
        timeout: 15
      )
      handle(response)
    end

    def get(path)
      response = HTTParty.get("#{base_url}#{path}", headers: headers, timeout: 15)
      handle(response)
    end

    def delete(path)
      response = HTTParty.delete("#{base_url}#{path}", headers: headers, timeout: 15)
      handle(response)
    end

    def headers
      { 'Content-Type' => 'application/json', 'apikey' => api_key }
    end

    def handle(response)
      raise ApiError.new(response.code, response.body) unless response.code.between?(200, 299)

      response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
    end
  end
end
# FORK:END
