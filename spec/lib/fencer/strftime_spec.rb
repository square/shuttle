# Copyright 2014 Square Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

require 'spec_helper'

describe Fencer::Strftime do
  describe ".fence" do
    it "should properly fence the examples from the Ruby docs" do
      expect(Fencer::Strftime.fence('%c - date and time (%a %b %e %T %Y)')).
          to eql("%1$c"=>[0..1], "%2$a"=>[20..21], "%3$b"=>[23..24], "%4$e"=>[26..27], "%5$T"=>[29..30], "%6$Y"=>[32..33])
      expect(Fencer::Strftime.fence('%D - Date (%m/%d/%y)')).
          to eql("%1$D"=>[0..1], "%2$m"=>[11..12], "%3$d"=>[14..15], "%4$y"=>[17..18])
      expect(Fencer::Strftime.fence('%F - The ISO 8601 date format (%Y-%m-%d)')).
          to eql("%1$F"=>[0..1], "%2$Y"=>[31..32], "%3$m"=>[34..35], "%4$d"=>[37..38])
      expect(Fencer::Strftime.fence('%v - VMS date (%e-%^b-%4Y)')).
          to eql("%1$v"=>[0..1], "%2$e"=>[15..16], "%3$^b"=>[18..20], "%4$4Y"=>[22..24])
      expect(Fencer::Strftime.fence('%x - Same as %D')).
          to eql("%1$x"=>[0..1], "%2$D"=>[13..14])
      expect(Fencer::Strftime.fence('%X - Same as %T')).
          to eql("%1$X"=>[0..1], "%2$T"=>[13..14])
      expect(Fencer::Strftime.fence('%r - 12-hour time (%I:%M:%S %p)')).
          to eql("%1$r"=>[0..1], "%2$I"=>[19..20], "%3$M"=>[22..23], "%4$S"=>[25..26], "%5$p"=>[28..29])
      expect(Fencer::Strftime.fence('%R - 24-hour time (%H:%M)')).
          to eql("%1$R"=>[0..1], "%2$H"=>[19..20], "%3$M"=>[22..23])
      expect(Fencer::Strftime.fence('%T - 24-hour time (%H:%M:%S)')).
          to eql("%1$T"=>[0..1], "%2$H"=>[19..20], "%3$M"=>[22..23], "%4$S"=>[25..26])
    end

    it "should handle %% tokens adjacent to format strings" do
      # given a "%%" next to what happens to be a valid format string,
      # e.g., "%%Y", the '%%' should be fenced and the 'Y' treated as literal.

      expect(Fencer::Strftime.fence('Hello %%World')).
          to eql("%1$%"=>[6..7])
    end
  end
end
