# Provides a simple pass-through localizer for RecordSelect. If you want
# to localize RS, you need to override this method and route it to your
# own system.
class Object
  def rs_(key, options = {})
    unless key.blank?
      text = I18n.translate "#{key}", **{:scope => [:record_select], :default => key.is_a?(String) ? key : key.to_s.titleize}.merge(options)
      # text = nil if text.include?('translation missing:')
    end
    text ||= key
    text
  end
end
