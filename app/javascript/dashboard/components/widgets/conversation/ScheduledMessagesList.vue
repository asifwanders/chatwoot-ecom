<script setup>
// FORK NOTE: Fork-only. Renders pending ScheduledMessage rows above composer
// with a cancel button each.
import { computed, onMounted, watch } from 'vue';
import { useStore } from 'vuex';

const props = defineProps({
  conversationId: { type: [Number, String], required: true },
});

const store = useStore();
const rows = computed(() =>
  store.getters['scheduledMessages/forConversation'](props.conversationId)
);

const refresh = () => store.dispatch('scheduledMessages/fetch', props.conversationId);

onMounted(refresh);
watch(() => props.conversationId, refresh);

const cancel = id =>
  store.dispatch('scheduledMessages/cancel', { conversationId: props.conversationId, id });

const formatTime = iso => new Date(iso).toLocaleString();
</script>

<template>
  <div v-if="rows.length" class="mx-2 mb-2 rounded-lg border border-n-weak bg-n-alpha-2 p-2 text-sm">
    <div class="mb-1 font-medium text-n-slate-12">
      {{ $t('CONVERSATION.SCHEDULED_MESSAGES.HEADER') }}
    </div>
    <ul class="space-y-1">
      <li
        v-for="row in rows"
        :key="row.id"
        class="flex items-start justify-between gap-2 rounded bg-n-solid-1 p-2"
      >
        <div class="flex-1">
          <div class="text-n-slate-12">{{ row.content }}</div>
          <div class="text-xs text-n-slate-11">{{ formatTime(row.send_at) }}</div>
        </div>
        <button
          type="button"
          class="text-xs text-n-ruby-9 hover:underline"
          @click="cancel(row.id)"
        >
          {{ $t('CONVERSATION.SCHEDULED_MESSAGES.CANCEL') }}
        </button>
      </li>
    </ul>
  </div>
</template>
