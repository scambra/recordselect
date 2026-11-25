# frozen_string_literal: true

require 'cgi'
require 'json'
require 'rack'

module RecordSelectJavascript
  # Serve real assets and deterministic responses without booting a host Rails app.
  class App
    ROOT = File.expand_path('../..', __dir__)
    JQUERY_ROOT = Gem::Specification.find_by_name('jquery-rails').full_gem_path
    ASSETS = {
      '/assets/jquery.js' => File.join(JQUERY_ROOT, 'vendor/assets/javascripts/jquery.js'),
      '/assets/jquery_ujs.js' => File.join(JQUERY_ROOT, 'vendor/assets/javascripts/jquery_ujs.js'),
      '/assets/jquery.visible.min.js' => File.join(ROOT, 'vendor/assets/javascripts/jquery.visible.min.js'),
      '/assets/record_select.js' => File.join(ROOT, 'app/assets/javascripts/record_select.js')
    }.freeze
    RECORDS = [[7, 'Alice', 'Engineer'], [8, 'Bob', 'Designer'], [9, 'Carol', 'Manager']].freeze

    def call(env)
      request = Rack::Request.new(env)
      if ASSETS.key?(request.path)
        response('text/javascript', File.read(ASSETS.fetch(request.path)))
      elsif request.path == '/'
        response('text/html', document(request.params))
      elsif request.path == '/users/browse'
        browse(request.params)
      else
        [404, {'content-type' => 'text/plain'}, ['Not found']]
      end
    end

    private

    def response(type, body)
      [200, {'content-type' => "#{type}; charset=utf-8", 'cache-control' => 'no-store'}, [body]]
    end

    def document(params)
      options = {id: 'record-select-users', min_length: params.fetch('min_length', '0').to_i}
      single = options.merge(onchange: 'changed', field_name: 'user_label')
      single.merge!(id: 7, label: 'Alice') if params['selected']
      multiple = options.merge(current: params['selected'] ? [{id: 7, label: 'Alice'}] : [])
      autocomplete = options.merge(onchange: 'changed', label: params['selected'] ? 'Alice' : nil)
      <<~HTML
        <!doctype html>
        <html><head><meta charset="utf-8"><title>RecordSelect JavaScript tests</title>
        <link rel="icon" href="data:,">
        <style>
          .widget { margin: 20px; }
          .record-select-container { position: absolute; background: white; border: 1px solid; z-index: 10; }
          .record.current { background: #ddd; }
          #outside { position: fixed; right: 20px; top: 20px; }
        </style>
        <script>#{instrumentation}</script>
        <script src="/assets/jquery.js"></script>
        <script src="/assets/jquery_ujs.js"></script>
        <script src="/assets/jquery.visible.min.js"></script>
        <script src="/assets/record_select.js"></script>
        <script>
          RecordSelect.registerCallback('changed', function(id, value, text, item) {
            window.callbackCalls.push({id: id, value: value, text: text, item: item.attr('id'), context: this.obj.attr('id')});
          });
          RecordSelect.registerCallback('dialogSelected', function(id, value, text, item) {
            window.callbackCalls.push({id: id, value: value, text: text, item: item.attr('id'), context: this.obj.attr('id')});
            return window.allowDialogClose;
          });
          jQuery(document).on('ajaxSend', function(event, xhr, settings) { window.requests.push(settings.url); });
          jQuery(document).on('ajaxComplete', function() { window.completedRequests++; });
          jQuery(document).on('recordselect:change recordselect:add recordselect:remove recordselect:unset', function(event, id, value) {
            window.widgetEvents.push({type: event.type, id: typeof id === 'object' ? null : id, value: value});
          });
          jQuery(function() { document.documentElement.dataset.recordselectReady = 'true'; });
        </script></head><body>
          <div class="widget" id="single-widget">
            #{input('single', 'user_id', 'Single', single)}
            <button type="button" class="clear-input-button">Clear</button>
          </div>
          <div class="widget" id="autocomplete-widget">
            #{input('autocomplete', 'user_name', 'Autocomplete', autocomplete)}
          </div>
          <div class="widget" id="multiple-widget">
            #{input('multiple', 'user_ids[]', 'Multiple', multiple)}
            <input type="hidden" name="user_ids[]" value="">
            <ul class="record-select-list"></ul>
          </div>
          <div class="widget">
            <a id="dialog" href="#" data-rs-type="Dialog" data-rs-id="dialog" data-rs-url="/users/browse"
               data-rs-options="#{CGI.escapeHTML(options.merge(onselect: 'dialogSelected').to_json)}">Choose user</a>
          </div>
          <div class="widget">#{input('disabled', 'disabled_id', 'Single', options, disabled: true)}</div>
          <button type="button" id="outside">Outside</button>
        </body></html>
      HTML
    end

    def input(id, name, type, options, disabled: false)
      <<~HTML
        <input id="#{id}" name="#{name}" class="recordselect" autocomplete="off" data-rs-delay="0.08"
               data-rs-type="#{type}" data-rs-url="/users/browse" data-rs-options="#{CGI.escapeHTML(options.to_json)}" #{'disabled' if disabled}>
      HTML
    end

    def instrumentation
      <<~JS
        window.testErrors = [];
        window.requests = [];
        window.completedRequests = 0;
        window.callbackCalls = [];
        window.widgetEvents = [];
        window.allowDialogClose = true;
        window.addEventListener('error', function(event) { window.testErrors.push(event.message); });
        window.addEventListener('unhandledrejection', function(event) { window.testErrors.push(String(event.reason)); });
        window.alert = function(message) { window.testErrors.push(String(message)); };
      JS
    end

    def browse(params)
      list = result_list(params)
      if params['update']
        script = "RecordSelect.render_page('record-select-users', #{list.to_json});\n#{highlight}"
        response('text/javascript', script)
      else
        body = <<~HTML
          <div class="record-select" id="record-select-users">
            <form action="/users/browse" method="get" data-remote="true">
              <input class="text-input" name="search" autocomplete="off">
              <input type="hidden" name="page" value="1">
              <input type="hidden" name="update" value="1">
              <input type="hidden" name="rs_mode" value="begins">
            </form>
            #{list}
          </div><script>#{highlight}</script>
        HTML
        response('text/html', body)
      end
    end

    def result_list(params)
      search = params.fetch('search', '').downcase
      records = RECORDS.select do |_id, label, _description|
        params['rs_mode'] == 'contains' ? label.downcase.include?(search) : label.downcase.start_with?(search)
      end
      page = [params.fetch('page', '1').to_i, 1].max
      items = records.slice((page - 1) * 2, 2) || []
      rows = items.map do |id, label, description|
        "<li class=\"record\" id=\"rs#{id}\"><label> #{label} </label><span>#{description}</span></li>"
      end
      rows.unshift('<li class="found" data-searching="Searching">Records found</li>')
      rows << pagination('previous', page - 1, params) if page > 1
      rows << pagination('next', page + 1, params) if page * 2 < records.length
      mode = params['rs_mode'] == 'contains' ? 'begins' : 'contains'
      url = CGI.escapeHTML("/users/browse?#{Rack::Utils.build_query(params.merge('rs_mode' => mode, 'update' => '1'))}")
      rows << "<li><a class=\"rs-mode\" data-value=\"#{mode}\" data-remote=\"true\" href=\"#{url}\">#{mode}</a></li>"
      "<ol>#{rows.join}</ol>"
    end

    def pagination(direction, page, params)
      url = CGI.escapeHTML("/users/browse?#{Rack::Utils.build_query(params.merge('page' => page, 'update' => '1'))}")
      "<li class=\"pagination #{direction}\"><a data-remote=\"true\" href=\"#{url}\">#{direction}</a></li>"
    end

    def highlight
      "var item = jQuery('.record-select-container .record:first'); var rs = item.closest('.record-select-container').data('recordselect'); if (rs) rs.highlight(item);"
    end
  end
end
