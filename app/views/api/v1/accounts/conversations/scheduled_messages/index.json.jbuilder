json.data do
  json.array! @scheduled_messages, partial: 'scheduled_message', as: :scheduled_message
end
