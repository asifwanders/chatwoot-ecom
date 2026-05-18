require 'rails_helper'

RSpec.describe AutomationRules::ConditionsFilterService, 'custom_attribute_changed_to' do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:rule) do
    create(:automation_rule,
           account: account,
           event_name: 'conversation_updated',
           conditions: [
             {
               'attribute_key' => 'custom_attribute_changed_to',
               'filter_operator' => 'equal_to',
               'values' => [{ 'attribute_key' => 'order_status', 'to' => 'shipped' }],
               'query_operator' => nil
             }
           ],
           actions: [{ 'action_name' => 'add_label', 'action_params' => ['post-ship'] }])
  end

  def perform(diff)
    described_class.new(rule, conversation, changed_attributes: { 'custom_attributes' => diff }).perform
  end

  it 'matches when value transitions to target' do
    expect(perform([{ 'order_status' => 'packed' }, { 'order_status' => 'shipped' }])).to be true
  end

  it 'does not match when new value differs' do
    expect(perform([{ 'order_status' => 'packed' }, { 'order_status' => 'returned' }])).to be false
  end

  it 'does not match when value unchanged' do
    expect(perform([{ 'order_status' => 'shipped' }, { 'order_status' => 'shipped' }])).to be false
  end

  it 'respects from when supplied' do
    rule.conditions = [
      {
        'attribute_key' => 'custom_attribute_changed_to',
        'filter_operator' => 'equal_to',
        'values' => [{ 'attribute_key' => 'order_status', 'to' => 'shipped', 'from' => 'packed' }],
        'query_operator' => nil
      }
    ]
    rule.save!
    expect(perform([{ 'order_status' => 'pending' }, { 'order_status' => 'shipped' }])).to be false
    expect(perform([{ 'order_status' => 'packed' }, { 'order_status' => 'shipped' }])).to be true
  end
end
