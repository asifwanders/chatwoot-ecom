# Api::V1::Accounts::Conversations::ScheduledMessagesController
#
# REST surface for agent-facing scheduled-message UI.
#
# FORK NOTE: Fork-only. Routes appended (fenced) under the conversation scope
# in config/routes.rb.
class Api::V1::Accounts::Conversations::ScheduledMessagesController < Api::V1::Accounts::Conversations::BaseController
  before_action :set_scheduled_message, only: [:destroy]

  def index
    @scheduled_messages = @conversation.scheduled_messages.pending.order(send_at: :asc)
  end

  def create
    @scheduled_message = ScheduledMessages::CreateService.new(
      account: Current.account,
      conversation: @conversation,
      sender: Current.user,
      content: permitted_params[:content],
      send_at: permitted_params[:send_at],
      content_attributes: permitted_params[:content_attributes].to_h
    ).perform
  rescue ActiveRecord::RecordInvalid => e
    render_could_not_create_error(e.message)
  end

  def destroy
    @scheduled_message.cancel!('cancelled_by_user')
    head :no_content
  end

  private

  def set_scheduled_message
    @scheduled_message = @conversation.scheduled_messages.find(params[:id])
    authorize @scheduled_message, :destroy?
  end

  def permitted_params
    params.permit(:content, :send_at, content_attributes: {})
  end
end
