module RecordSelectHelper
  # If you use :params option, define this helper in your controller helpers
  # to return array with those params, so _list partial permits them
  def permit_rs_browse_params
  end

  def record_select_js(type:, id:, url:, options:)
    javascript_tag("new RecordSelect.#{type}(#{id.to_json}, #{url.to_json}, #{options.to_json});")
  end

  # Adds a link on the page that toggles a RecordSelect widget from the given controller.
  #
  # *Options*
  # +onselect+::  JavaScript code to handle selections client-side. This code has access to two variables: id, label. If the code returns false, the dialog will *not* close automatically.
  # +params+::    Extra URL parameters. If any parameter is a column name, the parameter will be used as a search term to filter the result set.
  # +html+::      Options for A tag
  # +rs+::        Options for RecordSelect constructor
  def link_to_record_select(name, controller, options = {})
    options[:params] ||= {}
    options[:params].merge!(:controller => controller, :action => :browse)
    options[:onselect] = "(function(id, label) {#{options[:onselect]}})" if options[:onselect]
    options[:html] ||= {}
    options[:html][:id] ||= "rs_#{rand(9999)}"
    js = options.include?(:js) ? options[:js] : request.xhr?

    controller = assert_controller_responds(options[:params][:controller])
    record_select_options = {id: record_select_id(controller.controller_path), onselect: options[:onselect] || ''}
    record_select_options.merge! options[:rs] if options[:rs]

    rs_data = {type: 'Dialog', id: options[:html][:id], url: url_for(options[:params]), options: record_select_options}
    options[:html][:data] = rs_data.transform_keys { |k| "rs_#{k}" } unless js
    html = link_to(name, '#', options[:html])
    html << record_select_js(**rs_data) if js

    html
  end

  # Adds a RecordSelect-based form field. The field submits the record's id using a hidden input.
  #
  # *Arguments*
  # +name+:: the input name that will be used to submit the selected record's id.
  # +current+:: the currently selected object. provide a new record if there're none currently selected and you have not passed the optional :controller argument.
  #
  # *Options*
  # +controller+::  The controller configured to provide the result set. Optional if you have standard resource controllers (e.g. UsersController for the User model), in which case the controller will be inferred from the class of +current+ (the second argument)
  # +params+::      A hash of extra URL parameters
  # +id+::          The id to use for the input. Defaults based on the input's name.
  # +field_name+::  The name to use for the text input. Defaults to '', so field is not submitted.
  # +rs+::          Options for RecordSelect constructor
  def record_select_field(name, current, options = {})
    options[:controller] ||= current.class.to_s.pluralize.underscore
    options[:params] ||= {}
    options[:id] ||= name.gsub(/[\[\]]/, '_')
    options[:class] ||= ''
    options[:class] << ' recordselect'
    options[:clear_button] = true unless options.include? :clear_button
    js = options.include?(:js) ? options.delete(:js) : request.xhr?

    controller = assert_controller_responds(options.delete(:controller))
    params = options.delete(:params)
    record_select_options = {id: record_select_id(controller.controller_path)}
    record_select_options[:field_name] = options.delete(:field_name) if options[:field_name]
    clear_button_class = 'clear-input-button'
    if current and not current.new_record?
      record_select_options[:id] = current.id
      record_select_options[:label] = label_for_field(current, controller)
      clear_button_class << ' enabled'
    end
    record_select_options.merge! options.delete(:rs) if options[:rs]

    clear_button = options.delete(:clear_button)
    options.merge!(autocomplete: 'off', onfocus: "this.focused=true", onblur: "this.focused=false")
    url = url_for({action: :browse, controller: controller.controller_path}.merge(params))
    rs_data = {type: 'Single', id: options[:id], url: url, options: record_select_options}
    options[:data] = rs_data.transform_keys { |k| "rs_#{k}" } unless js
    html = text_field_tag(name, nil, options)
    html << button_tag('x', type: :button, class: clear_button_class, aria_label: 'Clear input', title: 'Clear input') if clear_button
    html << record_select_js(**rs_data) if js

    html
  end

  # Adds a RecordSelect-based form field. The field is autocompleted.
  #
  # *Arguments*
  # +name+:: the input name that will be used to submit the selected value.
  # +current+:: the current object. provide a new record if there're none currently selected and you have not passed the optional :controller argument.
  #
  # *Options*
  # +controller+::  The controller configured to provide the result set. Optional if you have standard resource controllers (e.g. UsersController for the User model), in which case the controller will be inferred from the class of +current+ (the second argument)
  # +params+::      A hash of extra URL parameters
  # +id+::          The id to use for the input. Defaults based on the input's name.
  # +rs+::          Options for RecordSelect constructor
  def record_select_autocomplete(name, current, options = {})
    options[:controller] ||= current.class.to_s.pluralize.underscore
    options[:params] ||= {}
    options[:id] ||= name.gsub(/[\[\]]/, '_')
    options[:class] ||= ''
    options[:class] << ' recordselect'
    js = options.include?(:js) ? options.delete(:js) : request.xhr?

    controller = assert_controller_responds(options.delete(:controller))
    params = options.delete(:params)
    record_select_options = {id: record_select_id(controller.controller_path), label: options.delete(:label)}
    if current
      record_select_options[:label] ||= label_for_field(current, controller)
    end
    record_select_options.merge! options.delete(:rs) if options[:rs]

    options.merge!(autocomplete: 'off', onfocus: "this.focused=true", onblur: "this.focused=false")
    url = url_for({action: :browse, controller: controller.controller_path}.merge(params))
    rs_data = {type: 'Autocomplete', id: options[:id], url: url, options: record_select_options}
    options[:data] = rs_data.transform_keys { |k| "rs_#{k}" } unless js
    html = text_field_tag(name, nil, options)
    html << record_select_js(**rs_data) if js

    html
  end

  # Adds a RecordSelect-based form field for multiple selections. The values submit using a list of hidden inputs.
  #
  # *Arguments*
  # +name+:: the input name that will be used to submit the selected records' ids. empty brackets will be appended to the name.
  # +current+:: pass a collection of existing associated records
  #
  # *Options*
  # +controller+::  The controller configured to provide the result set.
  # +params+::      A hash of extra URL parameters
  # +id+::          The id to use for the input. Defaults based on the input's name.
  # +rs+::          Options for RecordSelect constructor
  def record_multi_select_field(name, current, options = {})
    options[:controller] ||= current.first.class.to_s.pluralize.underscore
    options[:params] ||= {}
    options[:id] ||= name.gsub(/[\[\]]/, '_')
    options[:class] ||= ''
    options[:class] << ' recordselect'
    options.delete(:name)
    js = options.include?(:js) ? options.delete(:js) : request.xhr?

    controller = assert_controller_responds(options.delete(:controller))
    params = options.delete(:params)
    record_select_options = {id: record_select_id(controller.controller_path)}
    record_select_options[:current] = current.inject([]) { |memo, record| memo.push({:id => record.id, :label => label_for_field(record, controller)}) }
    record_select_options.merge! options.delete(:rs) if options[:rs]

    options.merge!(autocomplete: 'off', onfocus: "this.focused=true", onblur: "this.focused=false")
    url = url_for({action: :browse, controller: controller.controller_path}.merge(params))
    rs_data = {type: 'Multiple', id: options[:id], url: url, options: record_select_options}
    options[:data] = rs_data.transform_keys { |k| "rs_#{k}" } unless js
    html = text_field_tag("#{name}[]", nil, options)
    html << hidden_field_tag("#{name}[]", '', id: nil)
    html << content_tag(:ul, '', class: 'record-select-list')
    html << record_select_js(**rs_data) if js

    html
  end

  # A helper to render RecordSelect partials
  def render_record_select(options = {}) #:nodoc:
    controller.send(:render_record_select, options) do |options|
      render options
    end
  end

  # Provides view access to the RecordSelect configuration
  def record_select_config #:nodoc:
    controller.send :record_select_config
  end

  def full_text_search?
    controller.send :full_text_search?
  end

  # The id of the RecordSelect widget for the given controller.
  def record_select_id(controller = nil) #:nodoc:
    controller ||= params[:controller]
    "record-select-#{controller.gsub('/', '_')}"
  end

  def record_select_search_id(controller = nil) #:nodoc:
    "#{record_select_id(controller)}-search"
  end

  private

  # uses renderer (defaults to record_select_config.label) to determine how the given record renders.
  def render_record_from_config(record, renderer = record_select_config.label)
    case renderer
    when Symbol, String
      # return full-html from the named partial
      render :partial => renderer.to_s, :locals => {:record => record}

    when Proc
      # return an html-cleaned descriptive string
      instance_exec record, &renderer
    end
  end

  # uses the result of render_record_from_config to snag an appropriate record label
  # to display in a field.
  #
  # if given a controller, searches for a partial in its views path
  def label_for_field(record, controller = self.controller)
    renderer = controller.record_select_config.label
    description = case renderer
    when Symbol, String
      # find the <label> element and grab its innerHTML
      render_record_from_config(record, File.join(controller.controller_path, renderer.to_s))

    when Proc
      # just return the string
      render_record_from_config(record, renderer)
    end
    description.match(/<label[^>]*>(.*)<\/label>/){ |match| match[1] } || description if description
  end

  def assert_controller_responds(controller_name)
    controller_name = "#{controller_name.camelize}Controller"
    controller = controller_name.constantize
    unless controller.uses_record_select?
      raise "#{controller_name} has not been configured to use RecordSelect."
    end
    controller
  end
end
