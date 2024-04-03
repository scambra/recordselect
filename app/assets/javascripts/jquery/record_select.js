if (typeof(Class) === 'undefined') {
  /* Simple Inheritance
   http://ejohn.org/blog/simple-javascript-inheritance/
  */
  (function(){
    var initializing = false, fnTest = /xyz/.test(function(){xyz;}) ? /\b_super\b/ : /.*/;

    // The base Class implementation (does nothing)
    this.Class = function(){};

    // Create a new Class that inherits from this class
    Class.extend = function(prop) {
      var _super = this.prototype;

      // Instantiate a base class (but only create the instance,
      // don't run the init constructor)
      initializing = true;
      var prototype = new this();
      initializing = false;

      // Copy the properties over onto the new prototype
      for (var name in prop) {
        // Check if we're overwriting an existing function
        prototype[name] = typeof prop[name] == "function" &&
          typeof _super[name] == "function" && fnTest.test(prop[name]) ?
          (function(name, fn){
            return function() {
              var tmp = this._super;

              // Add a new ._super() method that is the same method
              // but on the super-class
              this._super = _super[name];

              // The method only need to be bound temporarily, so we
              // remove it when we're done executing
              var ret = fn.apply(this, arguments);
              this._super = tmp;

              return ret;
            };
          })(name, prop[name]) :
          prop[name];
      }

      // The dummy class constructor
      function Class() {
        // All construction is actually done in the init method
        if ( !initializing && this.init )
          this.init.apply(this, arguments);
      }

      // Populate our constructed prototype object
      Class.prototype = prototype;

      // Enforce the constructor to be what we expect
      Class.constructor = Class;

      // And make this class extendable
      Class.extend = arguments.callee;

      return Class;
    };
  })();
}

/*
 jQuery delayed observer
 (c) 2007 - Maxime Haineault (max@centdessin.com)

 Special thanks to Stephen Goguen & Tane Piper.

 Slight modifications by Elliot Winkler
*/

if (typeof(jQuery.fn.delayedObserver) === 'undefined') {
  (function($){
    $.extend($.fn, {
      delayedObserver: function(callback, delay, options){
        return this.each(function(){
          var el = $(this);
          var op = options || {};
          el.data('oldval', el.val())
            .data('delay', delay === 0 ? delay : (delay || 0.5))
            .data('condition', op.condition || function() { return ($(this).data('oldval') == $(this).val()); })
            .data('callback', callback)
            [(op.event||'keyup')](function(){
              if (el.data('condition').apply(el)) { return; }
              else {
                if (el.data('timer')) { clearTimeout(el.data('timer')); }
                el.data('timer', setTimeout(function(){
                  var callback = el.data('callback');
                  if (callback) callback.apply(el);
                }, el.data('delay') * 1000));
                el.data('oldval', el.val());
              }
            });
        });
      }
    });
  })(jQuery);
}

jQuery(document).ready(function() {
  RecordSelect.document_loaded = true;
  jQuery(document).on('click', 'div.record-select li.record', function(event) {
    var link = jQuery(this);
    if (link.length) {
      RecordSelect.select_item(link);
      return false;
    }
    return true;
  });
  jQuery(document).on('click', '.record-select-option .remove', function(event) {
    var line = jQuery(this).parent(), value = line.find(':input:hidden').val();
    line.parent().data('recordselect').obj.trigger('recordselect:remove', [value]);
    line.remove();
    return false;
  });
  jQuery(document).on('ajax:beforeSend', '.record-select-container', function(event, xhr) {
    var rs = jQuery(this).data('recordselect'), cur = rs.current_xhr, found = jQuery(this).find('.found');
    jQuery(this).find('.record, .pagination').remove();
    found.html(found.data('searching'));
    rs.current_xhr = xhr;
    console.log(rs.current_xhr);
    if (cur) cur.abort();
  });
  jQuery(document).on('ajax:complete', '.record-select-container', function(event, xhr, status) {
    var rs = jQuery(this).data('recordselect');
    if (status != 'abort' || rs.current_xhr == xhr) {
      if (rs.is_open()) rs.show();
      rs.current_xhr = null;
    }
  });
  jQuery(document).on('click', 'input.recordselect ~ .clear-input-button', function() {
    var $clear_button = jQuery(event.target), $input = $clear_button.prevAll('input');
    if (!$input.length) return;
    $input.val('').removeClass('selected');
    $clear_button.removeClass('enabled');
  });
  jQuery(document).on('input recordselect:change', 'input.recordselect', function(event) {
    var $clear_button = jQuery(event.target).nextAll('.clear-input-button').first();
    if (!$clear_button.length) return;
    if (jQuery(event.target).val()) $clear_button.addClass('enabled');
    else $clear_button.removeClass('enabled');
  });
  jQuery(document).on('ajax:beforeSend', 'a.rs-mode', function() {
    $(this).closest('.record-select').find('form input[name="rs_mode"]').val($(this).data('value'));
  });
});

var RecordSelect = new Object();
RecordSelect.document_loaded = false;

RecordSelect.select_item = function(item) {
  var rs = item.closest('.record-select-handler').data('recordselect');
  if (rs) {
    try {
      var label = item.find('label').first().text().trim(), text = item.text().trim();
      rs.obj.focus();
      rs.onselect(item.attr('id').substr(2), label || text, text, item);
    } catch(e) {
      alert(e);
    }
  }
}

RecordSelect.observe = function(form) {
  if (typeof(form) == 'string') form = '#' + form;
  form = jQuery(form);
  var min_length = 0, rs = form.closest('.record-select-container').data('recordselect');
  if (rs) min_length = rs.min_length;
  var callback = function() {
    if (form.closest('body').length) form.trigger("submit");
  };
  var delay = parseFloat(rs.obj.data('rsDelay'));
  if (isNaN(delay)) delay = 0.35;
  form.find('input.text-input').delayedObserver(callback, delay, {
    condition: function() {
      var item = jQuery(this);
      return item.data('oldval') == item.val() || item.val().length < min_length;
    }
  }).on('paste', function() {
    if (form.closest('body').length) form.trigger("submit");
  });
}

RecordSelect.render_page = function(record_select_id, page) {
  jQuery('#' + record_select_id + ' ol').first().replaceWith(page);
};

RecordSelect.Abstract = Class.extend({
  /**
   * obj - the id or element that will anchor the recordselect to the page
   * url - the url to run the recordselect
   * options - ??? (check concrete classes)
   */
  init: function(obj, url, options) {
    if (typeof(obj) == 'string') obj = '#' + obj;
    this.obj = jQuery(obj);
    this.url = url;
    this.options = options;
    this.container;
    this.min_length = options.min_length || 0;
    if (this.options.onchange && typeof this.options.onchange != 'function') {
      this.options.onchange = eval(this.options.onchange);
    }
    if (this.options.onselect && typeof this.options.onselect != 'function') {
      this.options.onselect = eval(this.options.onselect);
    }

    if (RecordSelect.document_loaded) {
      this.onload();
    } else {
      var _this = this; jQuery(document).ready(function() { _this.onload(); })
    }
  },

  /**
   * Finish the setup - IE doesn't like doing certain things before the page loads
   * --override--
   */
  onload: function() {},

  /**
   * the onselect event handler - when someone clicks on a record
   * --override--
   */
  onselect: function(id, value, text, item) {
    alert(id + ': ' + value);
  },

  /**
   * opens the recordselect
   */
  open: function() {
    if (this.is_open()) return;
    var _this = this;
    jQuery.rails.fire(_this.obj, 'recordselect:before');
    _this.create_form();
    _this.container.show();
    var params = _this.obj.data('params'), text = _this.obj.val();

    var search_params = jQuery.param({search: text});
    params = params ? [params, search_params].join("&") : search_params;
    this.current_xhr = jQuery.ajax({
      url: this.url,
      data: params,
      success: function(data, status, xhr) {
        if (_this.current_xhr != xhr) return;
        if (status != 'abort') _this.current_xhr = null;
        _this.container.html(data);
        if (!_this.container.is(':visible')) _this.close();
        else {
          _this.container.find('.text-input').val(_this.obj.val());
          RecordSelect.observe(_this.container.find('form'));
          _this.container.hide(); // needed to get right document height to position first time
          if (text.length >= _this.min_length) _this.show();
        }
      }
    });
  },

  /**
   * positions and reveals the recordselect
   */
  show: function() {
    var offset = this.obj.offset(), scroll = jQuery(window).scrollTop(), window_height = jQuery(window).height();
    if (this.fixed) offset.top -= scroll; // get fixed position
    var top = this.obj.outerHeight() + offset.top, document_height = jQuery(document).height();

    this.container.show();
    var height = this.container.outerHeight();
    this.container.css('left', offset.left);
    this.container.css('top', '');
    this.container.css('bottom', '');
    if (this.above || (this.fixed || this.body_static) && top + height > window_height) {
      this.container.css('bottom', window_height - offset.top);
    } else {
      var below_space = window_height-(top-scroll), above_space = offset.top - scroll, position;
      if (below_space < height) {
        if (above_space >= height) position = 'bottom';
        else position = above_space < below_space ? 'top' : 'bottom';
      } else position = 'top';
      if (position == 'top') this.container.css('top', top);
      else {
        var bottom = document_height - offset.top, body_height = $(document.body).height();
        if (body_height < document_height) bottom -= document_height - body_height;
        this.container.css('bottom', bottom);
      }
    }

    if (this._use_iframe_mask()) {
      this.container.after('<iframe src="javascript:false;" class="record-select-mask" />');
      var mask = this.container.next('iframe');
      mask.css('left', this.container.css('left'))
          .css('top', this.container.css('top'));
    }

    if (this._use_iframe_mask()) {
      var dimensions = this.container.children().first();
      mask.css('width', dimensions.css('width'))
          .css('height', dimensions.css('height'));
    }
  },

  /**
   * closes the recordselect by emptying the container
   */
  close: function() {
    if (this._use_iframe_mask()) {
      this.container.next('iframe').remove();
    }

    this.container.hide();
    // hopefully by using remove() instead of innerHTML we won't leak memory
    this.container.children().remove();
  },

  /**
   * returns true/false for whether the recordselect is open
   */
  is_open: function() {
    return jQuery.trim(this.container.html()).length != 0;
  },

  /**
   * when the user clicks outside the dropdown
   */
  onbodyclick: function(event) {
    if (!this.is_open()) return;
    if (this.container.has(jQuery(event.target)).length > 0) {
      return;
    } else if (!this.obj.is(event.target)) {
      this.close();
    }
  },

  /**
   * creates and initializes (and returns) the recordselect container
   */
  create_container: function() {
    var e = jQuery("<div />", {'class': "record-select-container record-select-handler"}), rs = this;
    e.css('display', 'none');
    e.data('recordselect', rs);
    jQuery(this.obj).add(this.obj.parents()).each(function() {
      if (jQuery(this).css('position') == 'fixed') {
        rs.fixed = jQuery(this);
        e.css('position', 'fixed');
        return false;
      }
    });
    jQuery(this.obj).each(function() {
      if (jQuery(this).data('rs-above')) {
        rs.above = true;
        return false;
      }
    });
    jQuery(document.body).append(e);
    jQuery(document.body).mousedown(jQuery.proxy(this, "onbodyclick"));
    if (!rs.fixed && e.offsetParent().css('position') == 'static') rs.body_static = true;
    e.get(0).onselect = jQuery.proxy(this, "onselect")
    return e;
  },

  create_form: function() {
    var div = jQuery('<div>').addClass('record-select').attr('id', this.options.id);
    var form = jQuery('<form>').attr('action', this.url).attr('data-remote', true).attr('method', 'get');
    form.append(jQuery('<input type="text" name="search" class="text-input">'));
    form.append(jQuery('<input type="hidden" name="page" value="1">'));
    form.append(jQuery('<input type="hidden" name="update" value="1">'));
    div.append(form).append(jQuery('<ol>'));
    this.container.html(div);
    RecordSelect.observe(form);
  },

  onkeyup: function(event) {
    if (!this.is_open()) return;
    this.container.find('.text-input').val(this.obj.val()).trigger(event);
  },

  onpaste: function(event) {
    if (!this.is_open()) return;
    setTimeout(function () {
      this.container.find('.text-input').val(this.obj.val()).trigger(event);
    }.bind(this), 0);
  },

  /**
   * all the behavior to respond to a text field as a search box
   */
  _respond_to_text_field: function(text_field) {
    // attach the events to start this party
    text_field.focus(jQuery.proxy(this, 'open'));

    // the autosearch event - needs to happen slightly late (keyup is later than keypress)
    text_field.keyup(jQuery.proxy(this, 'onkeyup'));

    // the autosearch event - needs to happen slightly late (keyup is later than keypress)
    text_field.on('paste', jQuery.proxy(this, 'onpaste'));

    // keyboard navigation, if available
    if (this.onkeydown) {
      text_field.keydown(jQuery.proxy(this, "onkeydown"));
    }
  },

  _use_iframe_mask: function() {
    return this.container.insertAdjacentHTML ? true : false;
  }
});



/**
 * Adds keyboard navigation to RecordSelect objects
 */
jQuery.extend(RecordSelect.Abstract.prototype, {
  current: null,

  /**
   * keyboard navigation - where to intercept the keys is up to the concrete class
   */
  onkeydown: function(ev) {
    var elem;
    switch (ev.keyCode) {
      case 38: //Event.KEY_UP
        if (this.current && this.current.closest('html').length) elem = this.current.prev();
        if (!elem) elem = this.container.find('ol li.record').last();
        this.highlight(elem);
        break;
      case 40: //Event.KEY_DOWN
        if (this.current && this.current.closest('html').length) elem = this.current.next();
        if (!elem) elem = this.container.find('ol li.record').first();
        this.highlight(elem);
        break;
      case 13: // Event.KEY_RETURN
        if (this.current) this.current.click();
        break;
      case 39: // Event.KEY_RIGHT
        elem = this.container.find('li.pagination.next');
        if (elem) elem.find('a').click();
        break;
      case 37: // Event.KEY_LEFT
        elem = this.container.find('li.pagination.previous');
        if (elem) elem.find('a').click();
        break;
      case 27: // Event.KEY_ESC
      case 9: // Event.KEY_TAB
        this.close();
        break;
      default:
        return true;
    }
    if (ev.keyCode != 9) { // don't prevent tabbing
      ev.preventDefault(); // so "enter" doesn't submit the form, among other things(?)
    }
  },

  /**
   * moves the highlight to a new object
   */
  highlight: function(obj) {
    if (this.current) this.current.removeClass('current');
    this.current = jQuery(obj);
    obj.addClass('current');
  }
});

/**
 * Used by link_to_record_select
 * The options hash should contain a onselect: key, with a javascript function as value
 */
RecordSelect.Dialog = RecordSelect.Abstract.extend({
  onload: function() {
    this.container = this.create_container();
    this.obj.click(jQuery.proxy(this, "toggle"));
    if (this.onkeypress) this.obj.keypress(jQuery.proxy(this, 'onkeypress'));
  },

  onselect: function(id, value, text, item) {
    if (this.options.onselect(id, value, text, item) != false) this.close();
  },

  toggle: function(e) {
    e.preventDefault();
    if (this.is_open()) this.close();
    else this.open();
  }
});

/**
 * Used by record_select_field helper
 * The options hash may contain id: and label: keys, designating the current value
 * The options hash may also include an onchange: key, where the value is a javascript function (or eval-able string) for an callback routine
 * and field_name: key, where value will be set as name of the input field.
 */
RecordSelect.Single = RecordSelect.Abstract.extend({
  onload: function() {
    var rs = this;
    // initialize the container
    this.container = this.create_container();
    this.container.addClass('record-select-autocomplete');
    this.container.submit(function() {
      rs.hidden_input.val('');
      rs.obj.removeClass('selected');
      rs.obj.trigger('recordselect:unset', [rs]);
    });

    // create the hidden input
    this.obj.after('<input type="hidden" name="" value="" />');
    this.hidden_input = this.obj.next();

    // transfer the input name from the text input to the hidden input
    this.hidden_input.attr('name', this.obj.attr('name'));
    this.obj.attr('name', this.options.field_name || '');

    // initialize the values
    if (this.options.label) this.set(this.options.id, this.options.label);

    this._respond_to_text_field(this.obj);
    if (this.obj.prop('focused')) this.open(); // if it was focused before we could attach observers
  },

  onselect: function(id, value, text, item) {
    this.set(id, value);
    if (this.options.onchange) this.options.onchange.call(this, id, value, text, item);
    this.obj.trigger("recordselect:change", [id, value, text, item]);
    this.close();
  },

  /**
   * sets the id/label
   */
  set: function(id, label) {
    // unescaped html missing for label
    this.obj.val(label);
    this.hidden_input.val(id);
    this.obj.addClass('selected');
  }
});

/**
 * Used by record_select_autocomplete helper
 * The options hash may contain label: key, designating the current value
 * The options hash may also include an onchange: key, where the value is a javascript function (or eval-able string) for an callback routine.
 */
RecordSelect.Autocomplete = RecordSelect.Abstract.extend({
  onload: function() {
    // initialize the container
    this.container = this.create_container();
    this.container.addClass('record-select-autocomplete');

    // initialize the values
    if (this.options.label) this.set(this.options.label);

    this._respond_to_text_field(this.obj);
    if (this.obj.prop('focused')) this.open(); // if it was focused before we could attach observers
  },

  close: function() {
    // if they close the dialog with the text field empty, then delete the id value
    if (this.obj.val() == '') this.set('');

    RecordSelect.Abstract.prototype.close.call(this);
  },

  onselect: function(id, value, text, item) {
    this.set(value);
    if (this.options.onchange) this.options.onchange.call(this, id, value, text, item);
    this.obj.trigger("recordselect:change", [id, value, text, item]);
    this.close();
  },

  /**
   * sets the id/label
   */
  set: function(label) {
    // unescaped html missing for label
    this.obj.val(label);
  }
});

/**
 * Used by record_multi_select_field helper.
 * Options:
 *   list - the id (or object) of the <ul> to contain the <li>s of selected entries
 *   current - an array of id:/label: keys designating the currently selected entries
 */
RecordSelect.Multiple = RecordSelect.Abstract.extend({
  onload: function() {
    // initialize the container
    this.container = this.create_container();
    this.container.addClass('record-select-autocomplete');

    // decide where the <li> entries should be placed
    if (this.options.list) this.list_container = jQuery(this.options.list);
    else this.list_container = this.obj.siblings('ul');
    this.list_container.data('recordselect', this);

    // take the input name from the text input, and store it for this.add()
    this.input_name = this.obj.attr('name');
    this.obj.attr('name', '');

    // initialize the list
    for(var i = 0, length = this.options.current.length; i < length; i++) {
      this.add(this.options.current[i].id, this.options.current[i].label);
    }

    this._respond_to_text_field(this.obj);
    if (this.obj.prop('focused')) this.open(); // if it was focused before we could attach observers
  },

  onselect: function(id, value, text, item) {
    this.add(id, value);
    this.obj.trigger("recordselect:add", [id, value, text, item]);
  },

  /**
   * Adds a record to the selected list
   */
  add: function(id, label) {
    // return silently if this value has already been selected
    if (this.list_container.has('input[value=' + id + ']').length > 0) return;

    var entry = '<li class="record-select-option">'
              + '<a href="#" class="remove">remove</a>'
              + '<input type="hidden" name="' + this.input_name + '" value="' + id + '" />'
              + '<label>' + label + '</label>'
              + '</li>';
    this.list_container.prepend(entry)
  }
});
