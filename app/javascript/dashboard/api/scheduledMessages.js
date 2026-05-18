/* global axios */
// FORK NOTE: Fork-only API client for ScheduledMessage CRUD.
import ApiClient from './ApiClient';

class ScheduledMessagesAPI extends ApiClient {
  constructor() {
    super('conversations', { accountScoped: true });
  }

  base(conversationId) {
    return `${this.url}/${conversationId}/scheduled_messages`;
  }

  list(conversationId) {
    return axios.get(this.base(conversationId));
  }

  create(conversationId, { content, sendAt, contentAttributes = {} }) {
    return axios.post(this.base(conversationId), {
      content,
      send_at: sendAt,
      content_attributes: contentAttributes,
    });
  }

  cancel(conversationId, id) {
    return axios.delete(`${this.base(conversationId)}/${id}`);
  }
}

export default new ScheduledMessagesAPI();
