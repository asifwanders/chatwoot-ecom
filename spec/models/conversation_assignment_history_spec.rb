require 'rails_helper'

RSpec.describe ConversationAssignmentHistory do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }

  it 'persists with valid attributes' do
    history = described_class.create!(
      conversation: conversation,
      account: account,
      source: 'manual',
      assigned_at: Time.current
    )
    expect(history).to be_persisted
  end

  it 'rejects unknown source' do
    record = described_class.new(
      conversation: conversation,
      account: account,
      source: 'bogus',
      assigned_at: Time.current
    )
    expect(record).not_to be_valid
  end

  describe '.for_conversation' do
    it 'returns rows newest-first' do
      older = described_class.create!(conversation: conversation, account: account, source: 'manual', assigned_at: 1.hour.ago)
      newer = described_class.create!(conversation: conversation, account: account, source: 'manual', assigned_at: 1.minute.ago)
      expect(described_class.for_conversation(conversation).to_a).to eq([newer, older])
    end
  end
end
