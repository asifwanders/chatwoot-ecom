require 'rails_helper'

RSpec.describe ConversationAssignmentHistoryListener do
  let(:listener) { described_class.instance }
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:team) { create(:team, account: account) }
  let(:conversation) { create(:conversation, account: account, assignee: agent, team: team) }

  def build_event(changed)
    Events::Base.new('conversation_updated', Time.zone.now,
                     conversation: conversation,
                     changed_attributes: changed,
                     performed_by: nil)
  end

  it 'creates a row when assignee_id changed' do
    expect { listener.conversation_updated(build_event('assignee_id' => [nil, agent.id])) }
      .to change(ConversationAssignmentHistory, :count).by(1)
  end

  it 'creates a row when team_id changed' do
    expect { listener.conversation_updated(build_event('team_id' => [nil, team.id])) }
      .to change(ConversationAssignmentHistory, :count).by(1)
  end

  it 'skips when neither assignee nor team changed' do
    expect { listener.conversation_updated(build_event('status' => %w[pending open])) }
      .not_to change(ConversationAssignmentHistory, :count)
  end

  it 'tags source automation when Current.executed_by is an AutomationRule' do
    rule = create(:automation_rule, account: account)
    Current.executed_by = rule
    listener.conversation_updated(build_event('assignee_id' => [nil, agent.id]))
    expect(ConversationAssignmentHistory.last.source).to eq('automation')
  ensure
    Current.reset
  end

  it 'tags source manual and records the performing user' do
    user = create(:user, account: account)
    event = Events::Base.new('conversation_updated', Time.zone.now,
                             conversation: conversation,
                             changed_attributes: { 'assignee_id' => [nil, agent.id] },
                             performed_by: user)
    listener.conversation_updated(event)
    history = ConversationAssignmentHistory.last
    expect(history.source).to eq('manual')
    expect(history.changed_by_user_id).to eq(user.id)
  end
end
