require 'rails_helper'

RSpec.describe ScheduledMessages::CreateService do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:conversation) { create(:conversation, account: account) }

  it 'persists row and enqueues delivery job' do
    expect do
      described_class.new(
        account: account, conversation: conversation, sender: user,
        content: 'later', send_at: 10.minutes.from_now
      ).perform
    end.to change(ScheduledMessage, :count).by(1)
      .and have_enqueued_job(ScheduledMessageJob)
  end
end
