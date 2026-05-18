<script setup>
// FORK NOTE: Fork-only popover. Lets agents schedule the current composer
// content for a future send_at. Three quick presets + free-form datetime.
import { ref, computed } from 'vue';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';

const props = defineProps({
  conversationId: { type: [Number, String], required: true },
  content: { type: String, default: '' },
});
const emit = defineEmits(['scheduled', 'close']);

const store = useStore();
const customDateTime = ref('');
const isSaving = ref(false);

const presets = computed(() => [
  { key: 'h1', label: '+1 hour', at: () => new Date(Date.now() + 60 * 60 * 1000) },
  {
    key: 'tom9',
    label: 'Tomorrow 9am',
    at: () => {
      const d = new Date();
      d.setDate(d.getDate() + 1);
      d.setHours(9, 0, 0, 0);
      return d;
    },
  },
  { key: 'd3', label: '+3 days', at: () => new Date(Date.now() + 3 * 24 * 60 * 60 * 1000) },
]);

const save = async sendAt => {
  if (!props.content || !props.content.trim()) {
    useAlert('Composer is empty');
    return;
  }
  isSaving.value = true;
  try {
    await store.dispatch('scheduledMessages/create', {
      conversationId: props.conversationId,
      content: props.content,
      sendAt: sendAt.toISOString(),
    });
    emit('scheduled');
    emit('close');
  } catch (e) {
    useAlert(e?.response?.data?.error || 'Failed to schedule');
  } finally {
    isSaving.value = false;
  }
};

const submitCustom = () => {
  const d = new Date(customDateTime.value);
  if (isNaN(d.getTime()) || d <= new Date()) {
    useAlert('Pick a future date/time');
    return;
  }
  save(d);
};
</script>

<template>
  <div class="absolute bottom-12 right-2 z-50 w-72 rounded-lg border border-n-weak bg-n-solid-1 p-3 shadow-lg">
    <div class="mb-2 text-sm font-medium text-n-slate-12">
      {{ $t('CONVERSATION.SCHEDULED_MESSAGES.TITLE') }}
    </div>
    <div class="mb-3 space-y-1">
      <button
        v-for="p in presets"
        :key="p.key"
        type="button"
        class="block w-full rounded p-1 text-left text-sm hover:bg-n-alpha-1"
        :disabled="isSaving"
        @click="save(p.at())"
      >
        {{ p.label }}
      </button>
    </div>
    <label class="block text-xs text-n-slate-11">
      {{ $t('CONVERSATION.SCHEDULED_MESSAGES.CUSTOM_LABEL') }}
    </label>
    <input
      v-model="customDateTime"
      type="datetime-local"
      class="mb-2 w-full rounded border border-n-weak bg-n-solid-1 px-2 py-1 text-sm"
    />
    <div class="flex justify-end gap-2">
      <button
        type="button"
        class="text-xs text-n-slate-11 hover:underline"
        @click="emit('close')"
      >
        {{ $t('CONVERSATION.SCHEDULED_MESSAGES.CANCEL') }}
      </button>
      <button
        type="button"
        class="rounded bg-n-brand px-2 py-1 text-xs text-white"
        :disabled="isSaving"
        @click="submitCustom"
      >
        {{ $t('CONVERSATION.SCHEDULED_MESSAGES.SAVE') }}
      </button>
    </div>
  </div>
</template>
