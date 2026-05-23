<script setup>
// FORK:BEGIN — fork-only component: agent signature account toggle
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import SectionLayout from './SectionLayout.vue';
import Switch from 'next/switch/Switch.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();
const isEnabled = ref(false);
const isSubmitting = ref(false);

const { currentAccount, updateAccount } = useAccount();

watch(
  currentAccount,
  () => {
    const { prepend_agent_signature } = currentAccount.value?.settings || {};
    isEnabled.value = !!prepend_agent_signature;
  },
  { deep: true, immediate: true }
);

const handleSave = async () => {
  try {
    isSubmitting.value = true;
    await updateAccount(
      { prepend_agent_signature: isEnabled.value },
      { silent: true }
    );
    useAlert(t('GENERAL_SETTINGS.FORM.AGENT_SIGNATURE.SAVED'));
  } catch (error) {
    useAlert(t('GENERAL_SETTINGS.FORM.AGENT_SIGNATURE.ERROR'));
  } finally {
    isSubmitting.value = false;
  }
};
// FORK:END
</script>

<template>
  <SectionLayout
    :title="t('GENERAL_SETTINGS.FORM.AGENT_SIGNATURE.TITLE')"
    :description="t('GENERAL_SETTINGS.FORM.AGENT_SIGNATURE.SUBTITLE')"
    with-border
  >
    <div class="flex items-center justify-between gap-4 py-2">
      <span class="text-sm text-n-slate-12">
        {{ t('GENERAL_SETTINGS.FORM.AGENT_SIGNATURE.ENABLED_LABEL') }}
      </span>
      <Switch v-model="isEnabled" />
    </div>
    <div class="flex">
      <NextButton
        blue
        :is-loading="isSubmitting"
        :label="t('GENERAL_SETTINGS.FORM.AGENT_SIGNATURE.SAVE')"
        @click="handleSave"
      />
    </div>
  </SectionLayout>
</template>
