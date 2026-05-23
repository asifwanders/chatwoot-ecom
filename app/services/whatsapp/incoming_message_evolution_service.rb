# FORK:BEGIN — Inbound webhook handler for Evolution-API (Baileys) provider.
# Translates Evolution's `messages.upsert` payload into Chatwoot contacts/conversations/messages.
class Whatsapp::IncomingMessageEvolutionService
  pattr_initialize [:inbox!, :params!]

  def perform
    return unless inbound_message?

    @waid = remote_jid.to_s.sub(/@s\.whatsapp\.net\z/, '')
    return if @waid.blank?

    return if Message.find_by(source_id: source_id).present?

    set_contact
    return if @contact.blank? || @contact.blocked?

    ActiveRecord::Base.transaction do
      set_conversation
      create_message
      attach_media
      @message.save!
    end
  end

  private

  def event
    params[:event] || params['event']
  end

  def data
    @data ||= (params[:data] || params['data'] || {}).with_indifferent_access
  end

  def key
    @key ||= (data[:key] || {}).with_indifferent_access
  end

  def message_payload
    @message_payload ||= (data[:message] || {}).with_indifferent_access
  end

  def inbound_message?
    return false unless event.to_s == 'messages.upsert'
    return false if key[:fromMe]

    message_payload.present?
  end

  def remote_jid
    key[:remoteJid]
  end

  def source_id
    key[:id].to_s
  end

  def push_name
    data[:pushName].presence || "+#{@waid}"
  end

  def text_content
    message_payload[:conversation].presence ||
      message_payload.dig(:extendedTextMessage, :text).presence ||
      message_payload.dig(:imageMessage, :caption).presence ||
      message_payload.dig(:videoMessage, :caption).presence ||
      message_payload.dig(:documentMessage, :caption).presence
  end

  def in_reply_to_external_id
    # Baileys v7 emits `contextInfo` at the top-level data object for plain
    # text replies (messageType=conversation). Older Baileys nests it under
    # the message-type key (extendedTextMessage, imageMessage, etc.). Check
    # every known location.
    data.dig(:contextInfo, :stanzaId).presence ||
      message_payload.dig(:extendedTextMessage, :contextInfo, :stanzaId).presence ||
      message_payload.dig(:imageMessage, :contextInfo, :stanzaId).presence ||
      message_payload.dig(:videoMessage, :contextInfo, :stanzaId).presence ||
      message_payload.dig(:documentMessage, :contextInfo, :stanzaId).presence ||
      message_payload.dig(:audioMessage, :contextInfo, :stanzaId).presence
  end

  def set_contact
    contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: @waid,
      inbox: inbox,
      contact_attributes: { name: push_name, phone_number: "+#{@waid}" }
    ).perform

    @contact_inbox = contact_inbox
    @contact = contact_inbox&.contact
  end

  def set_conversation
    @conversation = if inbox.lock_to_single_conversation
                      @contact_inbox.conversations.last
                    else
                      @contact_inbox.conversations.where.not(status: :resolved).last
                    end
    return if @conversation

    @conversation = ::Conversation.create!(
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      contact_id: @contact.id,
      contact_inbox_id: @contact_inbox.id
    )
  end

  def create_message
    content_attrs = {}
    content_attrs[:in_reply_to_external_id] = in_reply_to_external_id if in_reply_to_external_id.present?

    @message = @conversation.messages.build(
      content: text_content,
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      message_type: :incoming,
      sender: @contact,
      source_id: source_id,
      content_attributes: content_attrs
    )
  end

  def attach_media
    key_name, payload = find_media
    return if payload.blank?

    url = payload[:url] || payload[:directPath]
    return if url.blank?

    file = begin
      Down.download(url)
    rescue StandardError => e
      Rails.logger.warn("[EVOLUTION] media download failed: #{e.message}")
      nil
    end
    return if file.blank?

    @message.content ||= payload[:caption]
    @message.attachments.new(
      account_id: @message.account_id,
      file_type: file_type_for(key_name),
      file: {
        io: file,
        filename: file.original_filename || File.basename(url.split('?').first),
        content_type: payload[:mimetype] || file.content_type
      }
    )
  end

  def find_media
    %i[imageMessage audioMessage videoMessage documentMessage stickerMessage].each do |key_name|
      payload = message_payload[key_name]
      return [key_name, payload] if payload.present?
    end
    [nil, nil]
  end

  def file_type_for(key_name)
    case key_name
    when :imageMessage, :stickerMessage then :image
    when :audioMessage then :audio
    when :videoMessage then :video
    else :file
    end
  end
end
# FORK:END
