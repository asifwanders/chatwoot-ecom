require 'rails_helper'

RSpec.describe ScheduledMessage do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }

  it 'persists with valid attrs' do
    msg = described_class.create!(
      account: account, conversation: conversation,
      content: 'hi', send_at: 1.hour.from_now
    )
    expect(msg).to be_persisted
    expect(msg.status).to eq('pending')
  end

  it 'rejects send_at in past on create' do
    msg = described_class.new(
      account: account, conversation: conversation,
      content: 'hi', send_at: 1.minute.ago
    )
    expect(msg).not_to be_valid
  end

  it '#cancel! transitions to cancelled' do
    msg = described_class.create!(
      account: account, conversation: conversation,
      content: 'hi', send_at: 1.hour.from_now
    )
    msg.cancel!('agent')
    expect(msg.reload.status).to eq('cancelled')
    expect(msg.cancel_reason).to eq('agent')
  end

  it '.due returns pending rows whose send_at has passed' do
    past = described_class.new(
      account: account, conversation: conversation,
      content: 'hi', send_at: 5.seconds.from_now
    )
    past.save(validate: false)
    past.update_column(:send_at, 1.minute.ago)

    described_class.create!(account: account, conversation: conversation, content: 'later', send_at: 1.hour.from_now)
    expect(described_class.due).to eq([past])
  end
end
