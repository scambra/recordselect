# frozen_string_literal: true

require_relative '../support/javascript_test_case'

class RecordSelectBrowserTest < RecordSelectJavascript::TestCase
  def test_initializes_widgets_once_and_leaves_disabled_fields_alone
    assert_equal 4, evaluate("jQuery('.record-select-container').length")
    assert_no_selector '#single[data-rs-type]', visible: :all
    assert_selector '#disabled[data-rs-type="Single"]', visible: :all
    assert_equal 'user_id', evaluate("#{instance}.hidden_input.attr('name')")
    assert_equal 'user_label', page.find('#single')[:name]
    execute("jQuery('[data-rs-type]').each(function() { RecordSelect.from_attributes(jQuery(this)); });")
    assert_equal 4, evaluate("jQuery('.record-select-container').length")
  end

  def test_initial_selections_populate_single_multiple_and_autocomplete_fields
    page.visit('/?selected=1')
    assert_selector 'html[data-recordselect-ready="true"]'
    assert_field 'single', with: 'Alice'
    assert_field 'autocomplete', with: 'Alice'
    assert_selector '#single-widget input[type=hidden][name=user_id][value="7"]', visible: :all
    assert_selector '#multiple-widget .record-select-option label', text: 'Alice'
    assert_selector '#multiple-widget .record-select-option input[value="7"]', visible: :all
  end

  def test_callback_registry_resolves_functions_and_registered_names
    result = evaluate(<<~JS)
      (function() {
        var fn = function() {};
        RecordSelect.registerCallback('test', fn);
        return [RecordSelect.resolveCallback('test', 'onselect') === fn,
                RecordSelect.resolveCallback(fn, 'onchange') === fn,
                RecordSelect.resolveCallback(null, 'onchange')];
      })()
    JS
    assert_equal [true, true, nil], result
  end

  def test_callback_registry_rejects_invalid_and_inherited_callbacks
    result = evaluate(<<~JS)
      (function() {
        var errors = [];
        [function() { RecordSelect.registerCallback('bad', 'code'); },
         function() { RecordSelect.resolveCallback(42, 'onselect'); },
         function() { RecordSelect.resolveCallback('missing', 'onselect'); },
         function() { RecordSelect.resolveCallback('toString', 'onselect'); }].forEach(function(fn) {
          try { fn(); } catch (error) { errors.push([error.name, error.message]); }
        });
        return errors;
      })()
    JS
    assert_equal %w[TypeError TypeError Error Error], result.map(&:first)
    assert_match(/must be a function/, result[0][1])
    assert_match(/unknown callback missing/, result[2][1])
    assert_match(/unknown callback toString/, result[3][1])
  end

  def test_single_selection_updates_id_label_callback_and_change_event
    open_widget
    page.find('#rs7').click
    assert_field 'single', with: 'Alice'
    assert_selector '#single-widget input[type=hidden][value="7"]', visible: :all
    assert_selector '#single.selected'
    assert_no_selector '.record-select-container', visible: true
    assert_equal [{'id' => '7', 'value' => 'Alice', 'text' => 'Alice Engineer', 'item' => 'rs7', 'context' => 'single'}], evaluate('window.callbackCalls')
    assert_equal [{'type' => 'recordselect:change', 'id' => '7', 'value' => 'Alice'}], evaluate('window.widgetEvents')
    assert_selector '#single-widget .clear-input-button.enabled'
  end

  def test_clear_button_clears_the_submitted_id_and_visible_label
    open_widget
    page.find('#rs7').click
    page.find('#single-widget .clear-input-button').click
    assert_field 'single', with: ''
    assert_selector '#single-widget input[type=hidden][value=""]', visible: :all
    assert_no_selector '#single.selected'
    assert_no_selector '#single-widget .clear-input-button.enabled'
  end

  def test_autocomplete_submits_the_label_without_creating_an_id_field
    open_widget('autocomplete')
    page.find('#rs8').click
    assert_field 'autocomplete', with: 'Bob'
    assert_equal 'user_name', page.find('#autocomplete')[:name]
    assert_no_selector '#autocomplete-widget input[type=hidden]', visible: :all
    assert_equal 'autocomplete', evaluate('window.callbackCalls[0].context')
    assert_equal '8', evaluate('window.callbackCalls[0].id')
    assert_no_selector '.record-select-container', visible: true
  end

  def test_multiple_selection_adds_hidden_values_and_prevents_duplicates
    open_widget('multiple')
    page.find('#rs7').click
    page.find('#rs7').click
    page.find('#rs8').click
    assert_selector '#multiple-widget .record-select-option', count: 2
    assert_selector '#multiple-widget input[name="user_ids[]"][value="7"]', count: 1, visible: :all
    assert_selector '#multiple-widget input[name="user_ids[]"][value="8"]', count: 1, visible: :all
    assert_selector '.record-select-container', visible: true
    assert_equal 'recordselect:add', evaluate('window.widgetEvents[0].type')
  end

  def test_multiple_selection_removal_emits_the_removed_id
    open_widget('multiple')
    page.find('#rs7').click
    page.find('#outside').click
    page.find('#multiple-widget .remove').click
    assert_no_selector '#multiple-widget .record-select-option'
    assert_equal({'type' => 'recordselect:remove', 'id' => '7', 'value' => nil}, evaluate('window.widgetEvents[window.widgetEvents.length - 1]'))
    assert_selector '#multiple-widget input[type=hidden][name="user_ids[]"][value=""]', visible: :all
  end

  def test_dialog_callbacks_can_keep_the_dialog_open_or_allow_it_to_close
    execute('window.allowDialogClose = false;')
    open_widget('dialog')
    page.find('#rs7').click
    assert_selector '.record-select-container #rs7'
    assert_equal 'dialog', evaluate('window.callbackCalls[0].context')
    execute('window.allowDialogClose = true;')
    page.find('#rs8').click
    assert_no_selector '.record-select-container', visible: true
    assert_equal %w[7 8], evaluate('window.callbackCalls.map(function(call) { return call.id; })')
  end

  def test_keyboard_navigation_moves_highlight_and_enter_selects_the_record
    open_widget
    assert_selector '#rs7.current'
    page.find('#single').send_keys(:arrow_down)
    assert_selector '#rs8.current'
    assert_no_selector '#rs7.current'
    page.find('#single').send_keys(:arrow_up)
    assert_selector '#rs7.current'
    page.find('#single').send_keys(:enter)
    assert_field 'single', with: 'Alice'
    assert_selector '#single-widget input[type=hidden][value="7"]', visible: :all
  end

  def test_escape_tab_and_outside_click_close_the_dropdown
    open_widget
    page.find('#single').send_keys(:escape)
    assert_no_selector '.record-select-container', visible: true
    page.find('#outside').click
    open_widget
    page.find('#single').send_keys(:tab)
    assert_no_selector '.record-select-container', visible: true
    open_widget
    page.find('#outside').click
    assert_no_selector '.record-select-container', visible: true
  end

  def test_pagination_fetches_and_executes_remote_javascript
    open_widget
    page.find('.pagination.next a').click
    assert_selector '#rs9', text: 'Carol'
    assert_no_selector '#rs7'
    assert_selector '#rs9.current'
    page.find('.pagination.previous a').click
    assert_selector '#rs7', text: 'Alice'
    assert_selector '#rs8', text: 'Bob'
    assert_no_selector '#rs9'
    assert_equal 3, evaluate('window.requests.length')
  end

  def test_arrow_keys_follow_pagination_links
    open_widget
    page.find('#single').send_keys(:arrow_right)
    assert_selector '#rs9'
    page.find('#single').send_keys(:arrow_left)
    assert_selector '#rs7'
  end

  def test_search_debounces_typing_and_replaces_results
    open_widget
    execute(<<~JS)
      ['B', 'Bo', 'Bob'].forEach(function(value) { jQuery('#single').val(value).trigger('keyup'); });
    JS
    assert_selector '#rs8'
    assert_no_selector '#rs7'
    assert_equal 2, evaluate('window.requests.length')
    assert_equal 'Bob', evaluate("jQuery('.record-select-container .text-input').val()")
  end

  def test_search_submission_unsets_an_existing_single_selection
    open_widget
    page.find('#rs7').click
    page.find('#outside').click
    page.find('#single').click
    assert_selector '#rs7'
    page.fill_in 'single', with: 'Bob'
    assert_selector '#rs8'
    assert_no_selector '#rs7'
    assert_selector '#single-widget input[type=hidden][value=""]', visible: :all
    assert_no_selector '#single.selected'
    assert_includes evaluate('window.widgetEvents.map(function(event) { return event.type; })'), 'recordselect:unset'
  end

  def test_mode_toggle_updates_the_search_form_and_changes_search_behavior
    open_widget
    page.fill_in 'single', with: 'li'
    assert_no_selector '.record-select-container li.record'
    page.find('a.rs-mode').click
    assert_selector '#rs7', text: 'Alice'
    assert_selector '.record-select-container input[name=rs_mode][value=contains]', visible: :all
    assert_equal 'begins', page.find('a.rs-mode')['data-value']
  end

  def test_ajax_events_abort_previous_searches_and_ignore_aborted_completions
    open_widget
    result = evaluate(<<~JS)
      (function() {
        var rs = #{instance}, aborted = 0;
        var old = {abort: function() { aborted++; }};
        var current = {abort: function() {}};
        rs.current_xhr = old;
        rs.container.trigger('ajax:beforeSend', [current]);
        var searching = rs.container.find('.found').text();
        rs.container.trigger('ajax:complete', [old, 'abort']);
        var preserved = rs.current_xhr === current;
        rs.container.trigger('ajax:complete', [current, 'success']);
        return [aborted, searching, preserved, rs.current_xhr, rs.container.find('.record').length];
      })()
    JS
    assert_equal [1, 'Searching', true, nil, 0], result
  end

  def test_minimum_search_length_suppresses_short_queries
    page.visit('/?min_length=3')
    assert_selector 'html[data-recordselect-ready="true"]'
    page.find('#single').click
    page.fill_in 'single', with: 'Bob'
    assert_selector '#rs8'
    before = evaluate('window.requests.length')
    execute("jQuery('#single').val('Bo').trigger('keyup');")
    count = page.evaluate_async_script('var done = arguments[0]; setTimeout(function() { done(window.requests.length); }, 200);')
    assert_equal before, count
    assert_equal 'Bob', evaluate("jQuery('.record-select-container .text-input').data('oldval')")
  end

  def test_paste_searches_using_the_updated_input_value
    open_widget
    execute("jQuery('#single').val('Carol').trigger('paste');")
    assert_selector '#rs9'
    assert_no_selector '#rs7'
    assert_equal 'Carol', evaluate("jQuery('.record-select-container .text-input').val()")
    assert_equal 2, evaluate('window.requests.length')
  end

  def test_delayed_observer_accepts_zero_delay_and_ignores_unchanged_values
    result = page.evaluate_async_script(<<~JS)
      var done = arguments[0], calls = [];
      var input = jQuery('<input>').appendTo('body');
      input.delayedObserver(function() { calls.push(this.val()); }, 0);
      input.val('Alice').trigger('keyup');
      input.val('Bob').trigger('keyup').trigger('keyup');
      setTimeout(function() { done([calls, input.data('delay')]); }, 50);
    JS
    assert_equal [['Bob'], 0], result
  end

  def test_old_initial_responses_cannot_replace_a_newer_response
    result = evaluate(<<~JS)
      (function() {
        var rs = #{instance}, original = jQuery.ajax, requests = [];
        jQuery.ajax = function(options) {
          var xhr = {};
          requests.push({options: options, xhr: xhr});
          return xhr;
        };
        try {
          rs.open(); rs.close(); rs.open();
          requests[0].options.success('<div>Old results</div>', 'success', requests[0].xhr);
          var ignored = rs.container.text().indexOf('Old results') === -1;
          requests[1].options.success('<form><input class="text-input"></form><span>New results</span>', 'success', requests[1].xhr);
          requests[0].options.success('<div>Old results</div>', 'success', requests[0].xhr);
          return [ignored, rs.container.text(), rs.current_xhr];
        } finally { jQuery.ajax = original; }
      })()
    JS
    assert_equal [true, 'New results', nil], result
  end

  def test_a_response_arriving_after_close_does_not_reopen_the_dropdown
    result = evaluate(<<~JS)
      (function() {
        var rs = #{instance}, original = jQuery.ajax, pending, xhr = {};
        jQuery.ajax = function(options) { pending = options; return xhr; };
        try {
          rs.open(); rs.close();
          pending.success('<div>Late results</div>', 'success', xhr);
          return [rs.is_open(), rs.container.is(':visible'), rs.current_xhr];
        } finally { jQuery.ajax = original; }
      })()
    JS
    assert_equal [false, false, nil], result
  end

  def test_open_emits_before_event_and_sends_extra_parameters
    execute(<<~JS)
      jQuery('#single').data('params', 'company_id=42').on('recordselect:before', function(event, rs) {
        window.beforeWidget = rs.obj.attr('id');
      });
    JS
    open_widget
    assert_equal 'single', evaluate('window.beforeWidget')
    assert_includes evaluate('window.requests[0]'), 'company_id=42'
    assert_includes evaluate('window.requests[0]'), 'search='
  end
end
