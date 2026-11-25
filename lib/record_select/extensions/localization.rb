# frozen_string_literal: true

# Provides a simple pass-through localizer for RecordSelect. If you want
# to localize RS, you need to override this method and route it to your
# own system.
class Object
  def rs_(key, options = {})
    if key.present?
      defaults = {scope: [:record_select], default: key.is_a?(String) ? key : key.to_s.titleize}
      text = I18n.t(key.to_s, **defaults, **options)
      # text = nil if text.include?('translation missing:')
    end
    text ||= key
    text
  end
end
