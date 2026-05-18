// FORK NOTE: Fork-only Vuex module for scheduled messages.
// Keyed by conversationId → array of pending scheduled-message rows.
import ScheduledMessagesAPI from '../../api/scheduledMessages';

const state = {
  records: {}, // { [conversationId]: ScheduledMessage[] }
  uiFlags: { isFetching: false, isCreating: false },
};

export const getters = {
  forConversation: $state => conversationId =>
    $state.records[Number(conversationId)] || [],
  getUIFlags: $state => $state.uiFlags,
};

export const actions = {
  async fetch({ commit }, conversationId) {
    commit('SET_UI_FLAG', { isFetching: true });
    try {
      const { data } = await ScheduledMessagesAPI.list(conversationId);
      commit('SET_RECORDS', { conversationId, records: data.data || [] });
    } finally {
      commit('SET_UI_FLAG', { isFetching: false });
    }
  },
  async create({ commit }, { conversationId, ...payload }) {
    commit('SET_UI_FLAG', { isCreating: true });
    try {
      const { data } = await ScheduledMessagesAPI.create(conversationId, payload);
      commit('APPEND_RECORD', { conversationId, record: data });
      return data;
    } finally {
      commit('SET_UI_FLAG', { isCreating: false });
    }
  },
  async cancel({ commit }, { conversationId, id }) {
    await ScheduledMessagesAPI.cancel(conversationId, id);
    commit('REMOVE_RECORD', { conversationId, id });
  },
};

export const mutations = {
  SET_UI_FLAG($state, flag) {
    $state.uiFlags = { ...$state.uiFlags, ...flag };
  },
  SET_RECORDS($state, { conversationId, records }) {
    $state.records = { ...$state.records, [Number(conversationId)]: records };
  },
  APPEND_RECORD($state, { conversationId, record }) {
    const existing = $state.records[Number(conversationId)] || [];
    $state.records = {
      ...$state.records,
      [Number(conversationId)]: [...existing, record],
    };
  },
  REMOVE_RECORD($state, { conversationId, id }) {
    const existing = $state.records[Number(conversationId)] || [];
    $state.records = {
      ...$state.records,
      [Number(conversationId)]: existing.filter(r => r.id !== id),
    };
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
