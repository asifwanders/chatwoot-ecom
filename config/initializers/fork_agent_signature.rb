# Wires Fork::AgentSignaturePrepender into Message after Rails boots so the
# before_validation callback fires for every outgoing user message.
Rails.application.config.to_prepare do
  Message.include Fork::AgentSignaturePrepender unless Message.include?(Fork::AgentSignaturePrepender)
end
