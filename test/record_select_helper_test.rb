# frozen_string_literal: true

require_relative 'test_helper'
require 'bigdecimal'
require 'active_support/core_ext/object/json'
require 'action_view'
require 'record_select/helpers/record_select_helper'

class RecordSelectHelperTest < ActiveSupport::TestCase
  Record = Struct.new(:id, :to_label, :new_record?)

  def setup
    @view = ActionView::Base.empty
    @view.extend(RecordSelectHelper)
    config = Struct.new(:label).new(proc { |record| record.to_label })
    controller = Struct.new(:controller_path, :record_select_config).new('users', config)
    @view.define_singleton_method(:assert_controller_responds) { |_name| controller }
    @view.define_singleton_method(:url_for) { |_params| '/users/browse' }
    @view.define_singleton_method(:content_security_policy_nonce) { 'test-nonce' }
    @record = Record.new(7, 'Alice', false)
  end

  def test_single_field_preserves_classes_and_selected_record
    options = {controller: 'users', js: false, class: 'custom'}
    html = fragment(@view.record_select_field('order[user_id]', @record, options))
    input = html.at_css('input')
    widget = JSON.parse(input['data-rs-options'])

    assert_equal 'order[user_id]', input['name']
    assert_equal 'order_user_id_', input['id']
    assert_equal 'custom recordselect', input['class']
    assert_equal 'off', input['autocomplete']
    assert_equal 7, widget['id']
    assert_equal 'Alice', widget['label']
    assert_equal 'clear-input-button enabled', html.at_css('button')['class']
    assert_nil input['clear_button']
    assert_nil html.at_css('script')
  end

  def test_single_field_renders_javascript_and_can_omit_clear_button
    html = fragment(@view.record_select_field('user_id', @record, controller: 'users', js: true, clear_button: false))

    assert_nil html.at_css('button')
    assert_nil html.at_css('input')['data-rs-options']
    assert_includes html.at_css('script').text, 'new RecordSelect.Single('
    assert_equal 'test-nonce', html.at_css('script')['nonce']
  end

  def test_single_field_leaves_new_records_unselected
    html = fragment(@view.record_select_field('user_id', Record.new(nil, 'New', true), controller: 'users', js: false))
    widget = JSON.parse(html.at_css('input')['data-rs-options'])

    assert_equal 'record-select-users', widget['id']
    assert_nil widget['label']
    assert_equal 'clear-input-button', html.at_css('button')['class']
  end

  def test_autocomplete_preserves_explicit_label_and_widget_options
    options = {controller: 'users', js: false, label: 'Chosen', rs: {minimum_input_length: 3}}
    html = fragment(@view.record_select_autocomplete('user_id', @record, options))
    input = html.at_css('input')
    widget = JSON.parse(input['data-rs-options'])

    assert_equal 'Autocomplete', input['data-rs-type']
    assert_equal 'Chosen', widget['label']
    assert_equal 3, widget['minimum_input_length']
    assert_equal ' recordselect', input['class']
  end

  def test_multi_select_preserves_selections_and_hidden_input
    options = {controller: 'users', js: false, name: 'ignored'}
    html = fragment(@view.record_multi_select_field('user_ids', [@record], options))
    input = html.at_css('input[type=text]')
    widget = JSON.parse(input['data-rs-options'])

    assert_equal 'user_ids[]', input['name']
    assert_equal 'Multiple', input['data-rs-type']
    assert_equal [{'id' => 7, 'label' => 'Alice'}], widget['current']
    assert_equal 'user_ids[]', html.at_css('input[type=hidden]')['name']
    assert_equal '', html.at_css('input[type=hidden]')['value']
    assert_not_nil html.at_css('ul.record-select-list')
  end

  private

  def fragment(html)
    Nokogiri::HTML.fragment(html)
  end
end
