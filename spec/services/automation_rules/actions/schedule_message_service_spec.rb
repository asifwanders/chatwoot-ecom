require 'rails_helper'

RSpec.describe AutomationRules::Actions::ScheduleMessageService do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account, name: 'Alice') }
  let(:conversation) { create(:conversation, account: account, contact: contact) }
  let(:rule) { create(:automation_rule, account: account) }

  it 'schedules a message with interpolated contact name' do
    expect do
      described_class.new(
        rule: rule, conversation: conversation,
        params: { 'offset_seconds' => 60, 'content_template' => 'Hi {{contact.name}}!' }
      ).perform
    end.to change(ScheduledMessage, :count).by(1)
    msg = ScheduledMessage.last
    expect(msg.content).to eq('Hi Alice!')
    expect(msg.send_at).to be_within(5.seconds).of(Time.current + 60.seconds)
  end

  it 'no-ops on blank template' do
    expect do
      described_class.new(rule: rule, conversation: conversation, params: { 'content_template' => '' }).perform
    end.not_to change(ScheduledMessage, :count)
  end
end
