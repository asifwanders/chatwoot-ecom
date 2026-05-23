/* global axios */
// FORK NOTE: Fork-only API client for Channel::Whatsapp evolution provider.
import ApiClient from '../ApiClient';

class EvolutionWhatsappAPI extends ApiClient {
  // Path: /api/v2/accounts/:id/channels/whatsapp_evolution_channels
  constructor() {
    super('channels/whatsapp_evolution_channels', {
      accountScoped: true,
      apiVersion: 'v2',
    });
  }

  create({ name, phoneNumber }) {
    return axios.post(this.url, {
      whatsapp_evolution_channel: { name, phone_number: phoneNumber },
    });
  }

  qr(channelId) {
    return axios.get(`${this.url}/${channelId}/qr`);
  }

  status(channelId) {
    return axios.get(`${this.url}/${channelId}/status`);
  }

  reconnect(channelId) {
    return axios.post(`${this.url}/${channelId}/reconnect`);
  }

  disconnect(channelId) {
    return axios.post(`${this.url}/${channelId}/disconnect`);
  }
}

export default new EvolutionWhatsappAPI();
