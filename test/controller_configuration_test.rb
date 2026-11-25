# frozen_string_literal: true

require_relative 'test_helper'
require 'record_select/config'
require 'record_select/actions'
require 'record_select/conditions'

class RecordSelectControllerConfigurationTest < ActiveSupport::TestCase
  class MembersController
    include RecordSelect
  end

  def test_unconfigured_controllers_do_not_use_record_select
    assert_nil MembersController.record_select_config
    assert_not MembersController.uses_record_select?
  end

  def test_configuration_infers_the_model_and_installs_actions_and_conditions
    controller = Class.new(MembersController)
    controller.define_singleton_method(:to_s) { 'Admin::MembersController' }
    controller.record_select(search_on: :name)
    assert_equal 'member', controller.record_select_config.send(:klass)
    assert controller.uses_record_select?
    assert_includes controller.ancestors, RecordSelect::Actions
    assert_includes controller.ancestors, RecordSelect::Conditions
    assert_same controller.record_select_config, controller.new.send(:record_select_config)
  end

  def test_subclasses_inherit_configuration_and_can_override_it
    parent = Class.new(MembersController)
    parent.record_select(model: 'member', search_on: :name)
    child = Class.new(parent)
    assert_same parent.record_select_config, child.record_select_config
    child.record_select(model: 'account', search_on: :title)
    assert_equal 'account', child.record_select_config.send(:klass)
    assert_equal [:title], child.record_select_config.search_on
    assert_equal [:name], parent.record_select_config.search_on
  end

  def test_deprecator_is_reused
    assert_instance_of ActiveSupport::Deprecation, RecordSelect.deprecator
    assert_same RecordSelect.deprecator, RecordSelect.deprecator
  end
end
