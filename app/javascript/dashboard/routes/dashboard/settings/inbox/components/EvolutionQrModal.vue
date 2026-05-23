<script setup>
// FORK NOTE: Fork-only QR modal for Evolution-API WhatsApp setup & reconnect.
import { ref, computed, onMounted, onBeforeUnmount } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import EvolutionWhatsappAPI from 'dashboard/api/channel/evolutionWhatsapp';
import NextButton from 'dashboard/components-next/button/Button.vue';
import SpinnerLoader from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  channelId: { type: Number, required: true },
  mode: {
    type: String,
    default: 'setup',
    validator: v => ['setup', 'reconnect'].includes(v),
  },
});

const emit = defineEmits(['connected', 'close']);

const { t } = useI18n();

const base64 = ref('');
const pairingCode = ref('');
const state = ref('connecting');
const isLoadingQr = ref(true);
const secondsLeft = ref(30);
const isRefreshing = ref(false);
const pollIntervalId = ref(null);
const tickIntervalId = ref(null);
const lastRefreshAt = ref(0);
const pollStartedAt = ref(0);

const POLL_MS = 2000;
const QR_LIFETIME_S = 30;
const AUTO_REFRESH_AT_S = 25;
const FAIL_AFTER_S = 60;
const REFRESH_COOLDOWN_MS = 10_000;

const isConnected = computed(() => state.value === 'open');
const isFailed = computed(
  () =>
    state.value === 'close' &&
    pollStartedAt.value > 0 &&
    (Date.now() - pollStartedAt.value) / 1000 > FAIL_AFTER_S
);

const stopPolling = () => {
  if (pollIntervalId.value) {
    clearInterval(pollIntervalId.value);
    pollIntervalId.value = null;
  }
  if (tickIntervalId.value) {
    clearInterval(tickIntervalId.value);
    tickIntervalId.value = null;
  }
};

const applyQrPayload = data => {
  // Evolution returns base64 as a full `data:image/png;base64,...` URL already.
  // Strip any prefix so the <img :src=...> template can prepend its own
  // without doubling it.
  const raw = data?.base64 || '';
  base64.value = raw.replace(/^data:image\/png;base64,/, '');
  // Pairing code (8-char human shortcut) is only emitted when the user
  // opts into phone-number pairing; we don't, so this stays empty and the UI
  // hides the row. NEVER fall back to `data.code` — that's the raw Baileys
  // noise key, unusable by humans.
  pairingCode.value = data?.pairing_code || '';
  secondsLeft.value = QR_LIFETIME_S;
};

const fetchInitialQr = async () => {
  isLoadingQr.value = true;
  try {
    const fn =
      props.mode === 'reconnect'
        ? EvolutionWhatsappAPI.reconnect
        : EvolutionWhatsappAPI.qr;
    const { data } = await fn.call(EvolutionWhatsappAPI, props.channelId);
    applyQrPayload(data);
  } catch (error) {
    useAlert(
      error?.response?.data?.message ||
        error.message ||
        t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.ERROR_CREATE')
    );
  } finally {
    isLoadingQr.value = false;
  }
};

const refreshQr = async ({ force = false } = {}) => {
  const now = Date.now();
  if (!force && now - lastRefreshAt.value < REFRESH_COOLDOWN_MS) return;
  lastRefreshAt.value = now;
  isRefreshing.value = true;
  try {
    const fn =
      props.mode === 'reconnect'
        ? EvolutionWhatsappAPI.reconnect
        : EvolutionWhatsappAPI.qr;
    const { data } = await fn.call(EvolutionWhatsappAPI, props.channelId);
    applyQrPayload(data);
  } catch (error) {
    useAlert(
      error?.response?.data?.message ||
        error.message ||
        t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.QR_MODAL.STATUS_CLOSE')
    );
  } finally {
    isRefreshing.value = false;
  }
};

const pollStatus = async () => {
  try {
    const { data } = await EvolutionWhatsappAPI.status(props.channelId);
    state.value = data?.state || 'connecting';
    if (state.value === 'open') {
      stopPolling();
      setTimeout(() => emit('connected'), 1500);
    }
  } catch (_e) {
    // swallow; keep polling
  }
};

const tick = () => {
  if (secondsLeft.value > 0) {
    secondsLeft.value -= 1;
  }
  if (
    !isConnected.value &&
    secondsLeft.value === QR_LIFETIME_S - AUTO_REFRESH_AT_S
  ) {
    refreshQr({ force: true });
  }
};

const close = () => {
  stopPolling();
  emit('close');
};

onMounted(async () => {
  await fetchInitialQr();
  pollStartedAt.value = Date.now();
  pollIntervalId.value = setInterval(pollStatus, POLL_MS);
  tickIntervalId.value = setInterval(tick, 1000);
});

onBeforeUnmount(() => {
  stopPolling();
});
</script>

<template>
  <woot-modal :show="true" :on-close="close">
    <div class="p-6">
      <h3 class="mb-1 text-lg font-medium text-n-slate-12">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.QR_MODAL.TITLE') }}
      </h3>
      <p class="mb-6 text-sm text-n-slate-11">
        {{
          mode === 'reconnect'
            ? $t(
                'INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.QR_MODAL.DESCRIPTION_RECONNECT'
              )
            : $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.QR_MODAL.DESCRIPTION_SETUP')
        }}
      </p>

      <div class="flex flex-col items-center justify-center">
        <div
          v-if="isLoadingQr"
          class="flex items-center justify-center w-[280px] h-[280px]"
        >
          <SpinnerLoader />
        </div>

        <div
          v-else-if="isConnected"
          class="flex flex-col items-center justify-center w-[280px] h-[280px] text-center"
        >
          <div
            class="flex items-center justify-center mb-3 w-14 h-14 rounded-full bg-n-teal-3"
          >
            <span class="text-2xl text-n-teal-11">✓</span>
          </div>
          <p class="text-base font-medium text-n-slate-12">
            {{ $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.QR_MODAL.STATUS_OPEN') }}
          </p>
        </div>

        <div
          v-else-if="isFailed"
          class="flex flex-col items-center justify-center w-[280px] text-center"
        >
          <p class="mb-4 text-sm text-n-ruby-11">
            {{ $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.QR_MODAL.STATUS_CLOSE') }}
          </p>
          <NextButton
            solid
            blue
            :is-loading="isRefreshing"
            :label="
              $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.QR_MODAL.REFRESH_NOW')
            "
            @click="refreshQr({ force: true })"
          />
        </div>

        <img
          v-else-if="base64"
          :src="`data:image/png;base64,${base64}`"
          alt="QR"
          class="w-[280px] h-[280px]"
        />

        <p
          v-if="pairingCode && !isConnected && !isFailed"
          class="mt-3 text-sm text-n-slate-11"
        >
          {{
            $t(
              'INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.QR_MODAL.PAIRING_CODE_LABEL'
            )
          }}
          <span class="ml-1 font-mono text-n-slate-12">{{ pairingCode }}</span>
        </p>

        <div
          v-if="!isConnected && !isFailed && !isLoadingQr"
          class="flex items-center gap-3 mt-4"
        >
          <span class="text-xs text-n-slate-11">
            {{
              $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.QR_MODAL.REFRESHING_IN', {
                seconds: secondsLeft,
              })
            }}
          </span>
          <NextButton
            faded
            slate
            :is-loading="isRefreshing"
            :label="
              $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.QR_MODAL.REFRESH_NOW')
            "
            @click="refreshQr()"
          />
        </div>

        <p
          v-if="!isConnected && !isFailed && !isLoadingQr"
          class="mt-3 text-xs text-n-slate-10"
        >
          {{
            $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.QR_MODAL.STATUS_CONNECTING')
          }}
        </p>
      </div>

      <div class="flex justify-end mt-6">
        <NextButton
          color="slate"
          :label="$t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.QR_MODAL.CLOSE')"
          @click="close"
        />
      </div>
    </div>
  </woot-modal>
</template>
