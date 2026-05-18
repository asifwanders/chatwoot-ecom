require 'rails_helper'

# End-to-end test for the "Return to original CSR after shipping" rule.
# Models the user-described workflow: Alice → Shipping team handoff → mark
# shipped → conversation should auto-return to Alice.
RSpec.describe 'Return to previous agent automation', type: :model do
  let(:account) { create(:account) }
  let(:alice) { create(:user, account: account, role: :agent) }
  let(:shipping_agent) { create(:user, account: account, role: :agent) }
  let(:shipping_team) { create(:team, account: account, name: 'Shipping') }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: alice) }

  before do
    create(:inbox_member, inbox: inbox, user: alice)
    create(:inbox_member, inbox: inbox, user: shipping_agent)
    account.account_users.find_by(user: alice).update!(availability: :online)
    account.account_users.find_by(user: shipping_agent).update!(availability: :online)

    create(:custom_attribute_definition,
           attribute_key: 'order_status',
           account: account,
           attribute_model: 'conversation_attribute')

    create(:automation_rule,
           account: account,
           event_name: 'conversation_updated',
           name: 'Return to original CSR after shipping',
           conditions: [
             {
               'attribute_key' => 'custom_attribute_changed_to',
               'filter_operator' => 'equal_to',
               'values' => [{ 'attribute_key' => 'order_status', 'to' => 'shipped' }],
               'query_operator' => 'AND'
             },
             {
               'attribute_key' => 'team_id',
               'filter_operator' => 'equal_to',
               'values' => [shipping_team.id],
               'query_operator' => nil
             }
           ],
           actions: [
             { 'action_name' => 'assign_previous_agent', 'action_params' => [{ 'fallback' => 'leave_unassigned' }] }
           ])
  end

  it 'returns conversation to Alice after Shipping marks shipped' do
    # Hand off to Shipping
    conversation.update!(assignee: shipping_agent, team: shipping_team)
    # Allow async listener to write history row synchronously in test env
    perform_enqueued_jobs if respond_to?(:perform_enqueued_jobs)

    # Now Shipping marks shipped
    conversation.update!(custom_attributes: { 'order_status' => 'shipped' })
    perform_enqueued_jobs if respond_to?(:perform_enqueued_jobs)

    expect(conversation.reload.assignee_id).to eq(alice.id)
  end
end
