require 'rails_helper'

RSpec.describe AutomationRules::Actions::AssignPreviousTeamService do
  let(:account) { create(:account) }
  let(:csr) { create(:team, account: account) }
  let(:shipping) { create(:team, account: account) }
  let(:conversation) { create(:conversation, account: account, team: shipping) }
  let(:rule) { create(:automation_rule, account: account) }

  it 'switches back to most recent distinct prior team' do
    ConversationAssignmentHistory.create!(conversation: conversation, account: account, team_id: csr.id, source: 'manual', assigned_at: 2.hours.ago)
    ConversationAssignmentHistory.create!(conversation: conversation, account: account, team_id: shipping.id, source: 'manual', assigned_at: 1.hour.ago)

    described_class.new(rule: rule, conversation: conversation, params: {}).perform
    expect(conversation.reload.team_id).to eq(csr.id)
  end

  it 'leaves current team alone when no prior history' do
    described_class.new(rule: rule, conversation: conversation, params: {}).perform
    expect(conversation.reload.team_id).to eq(shipping.id)
  end
end
