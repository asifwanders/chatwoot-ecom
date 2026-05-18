require 'rails_helper'

RSpec.describe 'Scheduled Messages API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account, assignee: agent) }

  before do
    create(:inbox_member, inbox: conversation.inbox, user: agent)
  end

  describe 'POST /api/v1/accounts/:account_id/conversations/:conversation_id/scheduled_messages' do
    it 'creates a scheduled message' do
      post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/scheduled_messages",
           headers: agent.create_new_auth_token,
           params: { content: 'later', send_at: 10.minutes.from_now.iso8601 }
      expect(response).to have_http_status(:success)
      expect(ScheduledMessage.count).to eq(1)
    end

    it 'rejects past send_at' do
      post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/scheduled_messages",
           headers: agent.create_new_auth_token,
           params: { content: 'late', send_at: 1.minute.ago.iso8601 }
      expect(response).not_to have_http_status(:success)
    end
  end

  describe 'DELETE /:id' do
    it 'cancels' do
      scheduled = ScheduledMessage.create!(account: account, conversation: conversation, content: 'x', send_at: 1.hour.from_now)
      delete "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/scheduled_messages/#{scheduled.id}",
             headers: agent.create_new_auth_token
      expect(response).to have_http_status(:no_content)
      expect(scheduled.reload.status).to eq('cancelled')
    end
  end

  describe 'GET index' do
    it 'lists pending only' do
      ScheduledMessage.create!(account: account, conversation: conversation, content: 'a', send_at: 1.hour.from_now)
      ScheduledMessage.create!(account: account, conversation: conversation, content: 'b', send_at: 2.hours.from_now, status: 'sent')
      get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/scheduled_messages",
          headers: agent.create_new_auth_token
      expect(response).to have_http_status(:success)
      data = JSON.parse(response.body)['data']
      expect(data.size).to eq(1)
    end
  end
end
