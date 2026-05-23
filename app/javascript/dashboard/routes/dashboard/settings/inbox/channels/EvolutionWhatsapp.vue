<script setup>
// FORK NOTE: Fork-only wizard step for WhatsApp via Evolution-API (QR login).
import { ref, computed } from 'vue';
import { useStore } from 'vuex';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import { isPhoneE164OrEmpty } from 'shared/helpers/Validators';
import { useAlert } from 'dashboard/composables';
import EvolutionWhatsappAPI from 'dashboard/api/channel/evolutionWhatsapp';
import NextButton from 'dashboard/components-next/button/Button.vue';
import EvolutionQrModal from '../components/EvolutionQrModal.vue';

const router = useRouter();
const store = useStore();
const { t } = useI18n();

const inboxName = ref('');
const phoneNumber = ref('');
const isCreating = ref(false);
const createdInbox = ref(null);
const showQrModal = ref(false);

const rules = {
  inboxName: { required },
  phoneNumber: { required, isPhoneE164OrEmpty },
};

const v$ = useVuelidate(
  rules,
  { inboxName, phoneNumber },
  { $autoDirty: false }
);

const inboxId = computed(() => createdInbox.value?.id);

const submit = async () => {
  v$.value.$touch();
  if (v$.value.$invalid) return;

  isCreating.value = true;
  try {
    const { data } = await EvolutionWhatsappAPI.create({
      name: inboxName.value.trim(),
      phoneNumber: phoneNumber.value.trim(),
    });
    createdInbox.value = data;
    // Refresh store so the inbox list includes the new channel.
    store.dispatch('inboxes/get');
    showQrModal.value = true;
  } catch (error) {
    useAlert(
      error?.response?.data?.message ||
        error.message ||
        t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.ERROR_CREATE')
    );
  } finally {
    isCreating.value = false;
  }
};

const onConnected = () => {
  showQrModal.value = false;
  if (!createdInbox.value) return;
  router.replace({
    name: 'settings_inboxes_add_agents',
    params: { page: 'new', inbox_id: createdInbox.value.id },
  });
};

const onClose = () => {
  showQrModal.value = false;
};
</script>

<template>
  <div>
    <div class="mb-6">
      <h2 class="text-lg font-medium text-n-slate-12">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.TITLE') }}
      </h2>
      <p class="mt-1 text-sm leading-relaxed text-n-slate-11">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.DESCRIPTION') }}
      </p>
    </div>

    <form class="flex flex-col flex-wrap mx-0" @submit.prevent="submit">
      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: v$.inboxName.$error }">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.NAME_LABEL') }}
          <input
            v-model="inboxName"
            type="text"
            :placeholder="
              $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.NAME_PLACEHOLDER')
            "
            @blur="v$.inboxName.$touch"
          />
          <span v-if="v$.inboxName.$error" class="message">
            {{ $t('INBOX_MGMT.ADD.WHATSAPP.INBOX_NAME.ERROR') }}
          </span>
        </label>
      </div>

      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: v$.phoneNumber.$error }">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.PHONE_LABEL') }}
          <input
            v-model="phoneNumber"
            type="text"
            :placeholder="
              $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.PHONE_PLACEHOLDER')
            "
            @blur="v$.phoneNumber.$touch"
          />
          <span class="text-xs text-n-slate-11">
            {{ $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.PHONE_HINT') }}
          </span>
          <span v-if="v$.phoneNumber.$error" class="message">
            {{ $t('INBOX_MGMT.ADD.WHATSAPP.PHONE_NUMBER.ERROR') }}
          </span>
        </label>
      </div>

      <div class="mt-4 w-full">
        <NextButton
          type="submit"
          solid
          blue
          :is-loading="isCreating"
          :label="
            isCreating
              ? $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.CREATING')
              : $t('INBOX_MGMT.ADD.WHATSAPP.EVOLUTION.SUBMIT')
          "
        />
      </div>
    </form>

    <EvolutionQrModal
      v-if="showQrModal && inboxId"
      :channel-id="inboxId"
      mode="setup"
      @connected="onConnected"
      @close="onClose"
    />
  </div>
</template>
