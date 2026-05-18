# Fork Changes

Soft-fork additions on top of upstream `chatwoot/chatwoot:develop`. Designed
for minimal rebase pain: most changes are new files; every edit to an
upstream file is wrapped in `# FORK:BEGIN` / `# FORK:END` (or `// FORK:`)
fences with a one-line reason.

## Features

### 1. WhatsApp reply-to (Evolution API)

No fork code changed. Upstream already implements the full inbound + outbound
reply-to flow for the WhatsApp Cloud API adapter:

- Inbound: `app/services/whatsapp/incoming_message_service_helpers.rb#process_in_reply_to`
  reads `context.id` from the webhook → `content_attributes.in_reply_to_external_id`
  → `Message#ensure_in_reply_to` resolves to a local `in_reply_to`.
- Outbound: `app/services/whatsapp/providers/whatsapp_cloud_service.rb#whatsapp_reply_context`
  builds `context: { message_id: <source_id> }` on send.
- UI: `ReplyBox.vue` already wires `replyTo` state; `MessageBubble`
  (`components-next/message/bubbles/Base.vue`) renders the quoted snippet.

**Assumption to verify after deploy:** the Evolution-API → Chatwoot bridge
must forward `message.contextInfo.stanzaId` as Cloud-API-shape `context.id`,
and accept outbound `context: { message_id }` payloads. The Evolution fork at
`~/Desktop/evolution-api-for-chatwoot-ecom` is the place to add this
translation if missing. Follow-up: send a quote-reply from WhatsApp and
confirm `in_reply_to_external_id` ends up populated on the resulting Message.

### 2. Scheduled messages

Agents can schedule a composer message for future send via a popover above
the editor; pending rows render above the composer with a cancel button.
Backed by `ScheduledMessage` (model + table), `ScheduledMessageJob`
(Sidekiq, `wait_until: send_at`), and `ScheduledMessagesSweeperJob`
(sidekiq-cron, every minute) as belt-and-suspenders. Cancels itself if the
conversation has resolved by delivery time (hardcoded; see TODO in
`ScheduledMessages::DeliverService::CANCEL_ON_RESOLVE`).

REST surface: nested under conversations.
- `GET    /api/v1/accounts/:account_id/conversations/:conversation_id/scheduled_messages`
- `POST   /api/v1/accounts/:account_id/conversations/:conversation_id/scheduled_messages`
- `DELETE /api/v1/accounts/:account_id/conversations/:conversation_id/scheduled_messages/:id`

Also exposed as automation action `schedule_message` with Liquid
interpolation against contact/conversation/account drops.

### 3. Auto-reassign back to previous agent / team

Decomposed into three primitives:

1. **History spine** — `ConversationAssignmentHistory` model + listener on
   `conversation_updated`. Tags `source: 'automation'` when
   `Current.executed_by` is an `AutomationRule` (already populated by
   `AutomationRules::ActionService`).
2. **Transition condition** `custom_attribute_changed_to` — evaluated
   in-memory from `previous_changes['custom_attributes']` shape `[old, new]`
   per-key, since this isn't expressible in SQL. Bypasses the main SQL pass.
3. **Actions** `assign_previous_agent`, `assign_previous_team` — walk history
   newest-first; the agent variant checks online + inbox membership and
   applies a fallback strategy (`round_robin_previous_team` /
   `leave_unassigned` / `keep_current`).

Admin can build the "Return to original CSR after shipping" rule entirely in
the UI with no code. See `spec/integration/fork/return_to_previous_agent_spec.rb`.

## File map

### New files (additive, fork-only)

```
app/models/conversation_assignment_history.rb
app/models/scheduled_message.rb
app/listeners/conversation_assignment_history_listener.rb
app/jobs/scheduled_message_job.rb
app/jobs/scheduled_messages_sweeper_job.rb
app/services/scheduled_messages/create_service.rb
app/services/scheduled_messages/deliver_service.rb
app/services/automation_rules/actions/schedule_message_service.rb
app/services/automation_rules/actions/assign_previous_agent_service.rb
app/services/automation_rules/actions/assign_previous_team_service.rb
app/policies/scheduled_message_policy.rb
app/controllers/api/v1/accounts/conversations/scheduled_messages_controller.rb
app/views/api/v1/accounts/conversations/scheduled_messages/_scheduled_message.json.jbuilder
app/views/api/v1/accounts/conversations/scheduled_messages/index.json.jbuilder
app/views/api/v1/accounts/conversations/scheduled_messages/create.json.jbuilder
app/javascript/dashboard/api/scheduledMessages.js
app/javascript/dashboard/store/modules/scheduledMessages.js
app/javascript/dashboard/components/widgets/conversation/ScheduledMessagesList.vue
app/javascript/dashboard/components/widgets/conversation/ScheduleSendPopover.vue
db/migrate/20260518000000_create_conversation_assignment_histories.rb
db/migrate/20260518000100_create_scheduled_messages.rb
spec/models/conversation_assignment_history_spec.rb
spec/models/scheduled_message_spec.rb
spec/listeners/conversation_assignment_history_listener_spec.rb
spec/services/scheduled_messages/create_service_spec.rb
spec/services/scheduled_messages/deliver_service_spec.rb
spec/services/automation_rules/actions/schedule_message_service_spec.rb
spec/services/automation_rules/actions/assign_previous_agent_service_spec.rb
spec/services/automation_rules/actions/assign_previous_team_service_spec.rb
spec/services/automation_rules/custom_attribute_changed_to_spec.rb
spec/controllers/api/v1/accounts/conversations/scheduled_messages_controller_spec.rb
spec/integration/fork/return_to_previous_agent_spec.rb
```

### Edited upstream files (FORK fences only)

| File | Fenced edit |
|---|---|
| `app/dispatchers/async_dispatcher.rb` | Register `ConversationAssignmentHistoryListener` |
| `app/models/conversation.rb` | `has_many :scheduled_messages, :conversation_assignment_histories` |
| `app/models/automation_rule.rb` | Append fork conditions + actions to validations |
| `app/services/automation_rules/action_service.rb` | Dispatch methods for `schedule_message`, `assign_previous_agent`, `assign_previous_team` |
| `app/services/automation_rules/conditions_filter_service.rb` | In-memory eval for `custom_attribute_changed_to` |
| `app/services/automation_rules/condition_validation_service.rb` | Whitelist `custom_attribute_changed_to` |
| `config/routes.rb` | Nested `scheduled_messages` resource |
| `config/schedule.yml` | `scheduled_messages_sweeper_job` cron entry |
| `app/javascript/dashboard/store/index.js` | Register `scheduledMessages` Vuex module |
| `app/javascript/dashboard/components/widgets/conversation/ReplyBox.vue` | Mount list + popover + schedule button |
| `app/javascript/dashboard/components/widgets/AutomationActionInput.vue` | Render `schedule_message` + `fallback_strategy` input types |
| `app/javascript/dashboard/routes/dashboard/settings/automation/constants.js` | Register fork actions + condition |
| `app/javascript/dashboard/i18n/locale/en/automation.json` | Labels for new actions/condition |
| `app/javascript/dashboard/i18n/locale/en/conversation.json` | Labels for scheduled-messages UI |

## Rebase guide

Watch these upstream areas during `git rebase upstream/develop`:

1. **`app/services/whatsapp/`** — recent upstream activity (commit
   `6a7cbcf5b` fixed Cloud API reply-to). If upstream changes the inbound
   `process_in_reply_to` shape, no fork code breaks, but verify Evolution
   bridge still forwards `context.id` correctly.
2. **`app/services/automation_rules/`** — three fenced edits live here. If
   upstream introduces its own transition condition or scheduled-message
   action, migrate the rule data and delete the fork files.
3. **`app/models/automation_rule.rb`** — `actions_attributes` /
   `conditions_attributes` lists. Upstream may add entries; resolve by
   keeping both upstream and FORK fenced lists.
4. **`app/dispatchers/async_dispatcher.rb`** — upstream may add new
   listeners; keep the fork `ConversationAssignmentHistoryListener` line
   alongside.
5. **`app/javascript/dashboard/components/widgets/conversation/ReplyBox.vue`**
   — heavily edited upstream. The fork mounts new components inside a single
   fenced block at template top + one import line; conflicts likely
   resolvable by re-placing the fenced block.
6. **`config/routes.rb`** — single nested route line. Trivial conflict
   resolution.

## Enabling

All features are always-on once migrated. No feature flags.

- Run migrations: `bundle exec rails db:migrate`
- Restart Sidekiq (sidekiq-cron picks up `scheduled_messages_sweeper_job`).
- Restart web. Frontend rebuilds will pick up new components/Vuex module.

To stand up the "Return to original CSR after shipping" automation rule, do
it through Settings → Automation → Add rule (entirely in the UI). For the
`custom_attribute_changed_to` condition the values field accepts JSON, e.g.:

```json
{"attribute_key":"order_status","to":"shipped"}
```

Optional `from` key to scope to a specific source state.

## Known gaps / follow-ups

- **Evolution bridge shape verification** — see Feature 1.
- **Account setting for `cancel_scheduled_on_resolve`** — currently hardcoded
  `true` in `ScheduledMessages::DeliverService::CANCEL_ON_RESOLVE`. Expose
  via account settings once a UI is in scope.
- **Frontend JS specs** — repo's frontend test setup wasn't extended; new
  Vue components have no unit specs. Backend coverage is full.
- **Ruby toolchain on dev machine missing 3.4.4** — specs not executed
  locally during fork build; run `bundle exec rspec spec/models/scheduled_message_spec.rb spec/listeners/conversation_assignment_history_listener_spec.rb spec/services/automation_rules/ spec/services/scheduled_messages/ spec/controllers/api/v1/accounts/conversations/scheduled_messages_controller_spec.rb spec/integration/fork/` to verify.
