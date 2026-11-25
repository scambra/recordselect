# frozen_string_literal: true

require_relative 'test_helper'
require 'action_view'
require 'record_select/form_builder'

class RecordSelectFormBuilderTest < ActiveSupport::TestCase
  Reflection = Struct.new(:macro, :klass, :options, :association_foreign_key)
  Member = Class.new

  class Builder < ActionView::Helpers::FormBuilder
    include RecordSelect::FormBuilder
  end

  def build(macro, current, options = {})
    reflection = Reflection.new(macro, Member, options, 'member_id')
    object = Struct.new(:member).new(current)
    object.class.define_singleton_method(:reflect_on_association) { |_association| reflection }
    template = Object.new
    template.define_singleton_method(:record_select_field) { |*args| [:single, *args] }
    template.define_singleton_method(:record_multi_select_field) { |*args| [:multiple, *args] }
    Builder.new('order[line_items]', object, template, {})
  end

  def test_singular_associations_use_the_current_record_and_sanitized_id
    %i[belongs_to has_one].each do |macro|
      current = Member.new
      type, name, record, options = build(macro, current).record_select(:member)
      assert_equal :single, type
      assert_equal 'order[line_items][member_id]', name
      assert_same current, record
      assert_equal 'order_line_items_member', options[:id]
    end
  end

  def test_empty_singular_associations_supply_a_new_record
    result = build(:belongs_to, nil).record_select(:member)
    assert_instance_of Member, result[2]
  end

  def test_collections_use_plural_foreign_keys_and_an_inferred_controller
    current = [Member.new]
    type, name, records, options = build(:has_many, current).record_select(:member)
    assert_equal :multiple, type
    assert_equal 'order[line_items][member_ids]', name
    assert_same current, records
    assert_equal 'record_select_form_builder_test/members', options[:controller]
  end

  def test_custom_foreign_key_controller_and_id_are_preserved
    result = build(:has_and_belongs_to_many, [], foreign_key: 'person_id').record_select(:member, controller: 'people', id: 'custom')
    assert_equal 'order[line_items][person_ids]', result[1]
    assert_equal({controller: 'people', id: 'custom'}, result[3])
  end
end
