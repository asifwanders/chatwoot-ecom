<script setup>
// FORK NOTE: Fork-only status banner for Evolution-API WhatsApp channel.
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import EvolutionWhatsappAPI from 'dashboard/api/channel/evolutionWhatsapp';
import NextButton from 'dashboard/components-next/button/Button.vue';
import EvolutionQrModal from './EvolutionQrModal.vue';

const props = defineProps({
  channel: { type: Object, required: true },
});

const { t } = useI18n();

const state = ref('connecting');
const isBusy = ref(false);
const showQrModal = ref(false);
const showConfirm = ref(false);

const channelId = computed(() => props.channel?.id);

const pillClass = computed(() => {
  if (state.value === 'open') return 'bg-n-teal-3 text-n-teal-11';
  if (state.value === 'close') return 'bg-n-ruby-3 text-n-ruby-11';
  return 'bg-n-amber-3 text-n-amber-11';
});

const pillLabel = computed(() => {
  if (state.value === 'open')
    return t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.STATUS_BANNER.CONNECTED');
  if (state.value === 'close')
    return t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.STATUS_BANNER.DISCONNECTED');
  return t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.STATUS_BANNER.CONNECTING');
});

const fetchStatus = async () => {
  if (!channelId.value) return;
  try {
    const { data } = await EvolutionWhatsappAPI.status(channelId.value);
    state.value = data?.state || 'connecting';
  } catch (_e) {
    // ignore — leave previous state
  }
};

const onConnected = async () => {
  showQrModal.value = false;
  await fetchStatus();
};

const onReconnect = () => {
  showQrModal.value = true;
};

const onDisconnectClick = () => {
  showConfirm.value = true;
};

const confirmDisconnect = async () => {
  showConfirm.value = false;
  isBusy.value = true;
  try {
    await EvolutionWhatsappAPI.disconnect(channelId.value);
    await fetchStatus();
  } catch (error) {
    useAlert(
      error?.response?.data?.message ||
        error.message ||
        t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.STATUS_BANNER.ERROR_DISCONNECT')
    );
  } finally {
    isBusy.value = false;
  }
};

onMounted(fetchStatus);
</script>

<template>
  <div
    class="flex flex-col gap-2 p-4 mb-4 border rounded-xl border-n-weak bg-n-solid-1"
  >
    <div class="flex items-center justify-between gap-3">
      <div class="flex items-center gap-3">
        <span
          class="px-2 py-0.5 text-xs font-medium rounded-full"
          :class="pillClass"
        >
          {{ pillLabel }}
        </span>
        <span v-if="state === 'close'" class="text-sm text-n-slate-11">
          {{
            $t(
              'INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.STATUS_BANNER.DISCONNECTED_HELP'
            )
          }}
        </span>
      </div>
      <div class="flex items-center gap-2">
        <NextButton
          v-if="state !== 'open'"
          solid
          blue
          :is-loading="isBusy"
          :label="
            $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.STATUS_BANNER.RECONNECT')
          "
          @click="onReconnect"
        />
        <NextButton
          v-if="state === 'open'"
          faded
          ruby
          :is-loading="isBusy"
          :label="
            $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.STATUS_BANNER.DISCONNECT')
          "
          @click="onDisconnectClick"
        />
      </div>
    </div>

    <EvolutionQrModal
      v-if="showQrModal && channelId"
      :channel-id="channelId"
      mode="reconnect"
      @connected="onConnected"
      @close="showQrModal = false"
    />

    <woot-modal
      v-if="showConfirm"
      :show="showConfirm"
      :on-close="() => (showConfirm = false)"
    >
      <div class="p-6">
        <h3 class="mb-3 text-lg font-medium text-n-slate-12">
          {{
            $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.STATUS_BANNER.DISCONNECT')
          }}
        </h3>
        <p class="mb-6 text-sm text-n-slate-11">
          {{
            $t(
              'INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.STATUS_BANNER.DISCONNECT_CONFIRM'
            )
          }}
        </p>
        <div class="flex justify-end gap-2">
          <NextButton
            color="slate"
            :label="$t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.QR_MODAL.CLOSE')"
            @click="showConfirm = false"
          />
          <NextButton
            color="ruby"
            :is-loading="isBusy"
            :label="
              $t(
                'INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.STATUS_BANNER.DISCONNECT'
              )
            "
            @click="confirmDisconnect"
          />
        </div>
      </div>
    </woot-modal>
  </div>
</template>
