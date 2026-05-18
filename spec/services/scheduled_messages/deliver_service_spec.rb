require 'rails_helper'

RSpec.describe ScheduledMessages::DeliverService do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }

  def make_scheduled(send_at: 5.minutes.from_now)
    ScheduledMessage.create!(
      account: account, conversation: conversation,
      content: 'hello', send_at: send_at
    )
  end

  it 'delivers a Message and marks sent' do
    scheduled = make_scheduled
    expect { described_class.new(scheduled).perform }
      .to change { conversation.messages.count }.by(1)
    expect(scheduled.reload.status).to eq('sent')
    expect(scheduled.sent_message_id).to eq(conversation.messages.last.id)
  end

  it 'is idempotent on non-pending rows' do
    scheduled = make_scheduled
    scheduled.update!(status: 'sent')
    expect { described_class.new(scheduled).perform }
      .not_to change { conversation.messages.count }
  end

  it 'cancels when conversation already resolved' do
    scheduled = make_scheduled
    conversation.update!(status: :resolved)
    described_class.new(scheduled).perform
    expect(scheduled.reload.status).to eq('cancelled')
    expect(scheduled.cancel_reason).to eq('conversation_resolved')
  end
end
