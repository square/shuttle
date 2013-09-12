module Localizer
  class Xib3 < Storyboard
    def self.localizable?(project, key)
      key.source =~ /#{Regexp.escape project.base_rfc5646_locale}\.lproj\/[^\/]+\.xib$/ &&
          key.importer == 'xib3'
    end
  end
end
