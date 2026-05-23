# FORK:BEGIN — Evolution provider for Channel::Whatsapp
# Mirrors the interface of Whatsapp::Providers::WhatsappCloudService so it can
# be returned by Channel::Whatsapp#provider_service when provider == 'evolution'.
class Whatsapp::Providers::WhatsappEvolutionService < Whatsapp::Providers::BaseService
  def send_message(phone_number, message)
    @message = message
    number = normalize_number(phone_number)

    if message.attachments.present?
      send_attachments(number, message)
    else
      send_text(number, message)
    end
  rescue Evolution::ApiError => e
    handle_evolution_error(e, message)
    nil
  end

  def send_template(_phone_number, _template_info, _message)
    # Templates are a Meta-Cloud concept; Baileys-based Evolution does not use them.
    raise NotImplementedError, 'Templates are not supported by the Evolution provider'
  end

  def sync_templates
    # No-op — Evolution/Baileys has no template catalogue.
    whatsapp_channel.mark_message_templates_updated
    true
  end

  def validate_provider_config?
    whatsapp_channel.provider_config['instance_name'].present?
  end

  def api_headers
    {}
  end

  def media_url(media_id)
    # Evolution returns absolute media URLs in webhook payloads, so we pass through.
    media_id
  end

  private

  def instance_service
    @instance_service ||= Evolution::InstanceService.new(whatsapp_channel)
  end

  def normalize_number(value)
    value.to_s.sub(/@s\.whatsapp\.net\z/, '').sub(/\A\+/, '')
  end

  def quoted_for(message)
    reply_to = message.content_attributes[:in_reply_to_external_id]
    return nil if reply_to.blank?

    source_id = message.conversation&.contact_inbox&.source_id.to_s
    remote_jid = source_id.include?('@') ? source_id : "#{source_id}@s.whatsapp.net"
    { id: reply_to, remoteJid: remote_jid }
  end

  def send_text(number, message)
    response = instance_service.send_text(
      to: number,
      text: message.outgoing_content,
      quoted: quoted_for(message)
    )
    extract_message_id(response)
  end

  def send_attachments(number, message)
    first_attachment = message.attachments.first
    caption = message.outgoing_content if message.outgoing_content.present?

    response = instance_service.send_media(
      to: number,
      type: media_type_for(first_attachment),
      url: first_attachment.download_url,
      caption: caption,
      filename: filename_for(first_attachment)
    )

    # If there are extra attachments, send them sans caption.
    message.attachments[1..].to_a.each do |attachment|
      instance_service.send_media(
        to: number,
        type: media_type_for(attachment),
        url: attachment.download_url,
        filename: filename_for(attachment)
      )
    end

    extract_message_id(response)
  end

  def media_type_for(attachment)
    case attachment.file_type.to_s
    when 'image' then 'image'
    when 'audio' then 'audio'
    when 'video' then 'video'
    else 'document'
    end
  end

  def filename_for(attachment)
    return nil unless attachment.file.attached?

    attachment.file.filename.to_s
  end

  def extract_message_id(response)
    response.dig('key', 'id') || response['id']
  end

  def handle_evolution_error(error, message)
    Rails.logger.error("[EVOLUTION] send_message failed: #{error.message}")
    return if message.blank?

    message.external_error = error.message.to_s.first(255)
    message.status = :failed
    message.save!
  end
end
# FORK:END
