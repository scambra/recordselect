module RecordSelect
  class Engine < Rails::Engine
    initializer 'active_scaffold.action_controller' do
      ActiveSupport.on_load :action_controller do
        include RecordSelect
      end
    end

    initializer 'record_select.action_view' do
      ActiveSupport.on_load :action_view do
        include RecordSelectHelper
        ActionView::Helpers::FormBuilder.send(:include, RecordSelect::FormBuilder)
      end
    end

    initializer 'record_select.assets' do
      config.assets.precompile << 'record_select/next.gif' << 'record_select/previous.gif'
    end
  end
end
