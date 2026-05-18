require 'rails_helper'

RSpec.describe AutomationRules::Actions::AssignPreviousAgentService do
  let(:account) { create(:account) }
  let(:alice) { create(:user, account: account, role: :agent) }
  let(:bob) { create(:user, account: account, role: :agent) }
  let(:shipping) { create(:team, account: account) }
  let(:conversation) { create(:conversation, account: account, assignee: bob, team: shipping) }
  let(:rule) { create(:automation_rule, account: account) }

  before do
    create(:inbox_member, inbox: conversation.inbox, user: alice)
    create(:inbox_member, inbox: conversation.inbox, user: bob)
    account.account_users.find_by(user: alice).update!(availability: :online)
    account.account_users.find_by(user: bob).update!(availability: :online)
  end

  it 'reassigns to most recent prior agent that differs from current' do
    ConversationAssignmentHistory.create!(conversation: conversation, account: account, assignee_id: alice.id, source: 'manual', assigned_at: 2.hours.ago)
    ConversationAssignmentHistory.create!(conversation: conversation, account: account, assignee_id: bob.id, team_id: shipping.id, source: 'manual', assigned_at: 30.minutes.ago)

    described_class.new(rule: rule, conversation: conversation, params: {}).perform
    expect(conversation.reload.assignee_id).to eq(alice.id)
  end

  it 'falls back to leave_unassigned when no eligible prior agent' do
    described_class.new(rule: rule, conversation: conversation, params: { 'fallback' => 'leave_unassigned' }).perform
    expect(conversation.reload.assignee_id).to be_nil
  end

  it 'skips offline previous agent' do
    account.account_users.find_by(user: alice).update!(availability: :offline)
    ConversationAssignmentHistory.create!(conversation: conversation, account: account, assignee_id: alice.id, source: 'manual', assigned_at: 2.hours.ago)
    described_class.new(rule: rule, conversation: conversation, params: { 'fallback' => 'leave_unassigned' }).perform
    expect(conversation.reload.assignee_id).to be_nil
  end
end
