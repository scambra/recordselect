# frozen_string_literal: true

module ActionDispatch
  module Routing
    class Mapper
      module Base
        def record_select_routes
          get :browse, :on => :collection
        end
      end
    end
  end
end
