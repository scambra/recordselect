# frozen_string_literal: true

require_relative 'test_helper'

class RecordselectTest < ActiveSupport::TestCase
  JAVASCRIPT_PATH = File.expand_path('../app/assets/javascripts/record_select.js', __dir__)
  HELPERS_PATH = File.expand_path('../lib/record_select/helpers/record_select_helper.rb', __dir__)

  def test_exposes_callback_registry_availability
    require 'record_select'

    assert RecordSelect.callback_registry?
  end

  def test_callbacks_are_resolved_without_eval
    source = File.read(JAVASCRIPT_PATH)

    assert_includes source, 'RecordSelect.registerCallback = function(name, callback)'
    assert_includes source, "RecordSelect.resolveCallback(this.options.onselect, 'onselect')"
    assert_includes source, 'this.options.onselect.call(this, id, value, text, item)'
    assert_not_includes source, 'eval('
  end

  def test_link_data_is_preserved_when_record_select_attributes_are_added
    source = File.read(HELPERS_PATH)

    assert_includes source, '(options[:html][:data] || {}).merge'
    assert_not_includes source, '(function(id, label)'
  end
end
