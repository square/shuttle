# Copyright 2013 Square Inc.
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

describe Fencer::Printf do
  describe ".fence" do
    it "should correctly fence all examples from the printf documentation" do
      Fencer::Printf.fence(%|printf ("Characters: %c %c \n", 'a', 65);|).
          should eql('%c' => [21..22, 24..25])
      Fencer::Printf.fence(%|printf ("Decimals: %d %ld\n", 1977, 650000L);|).
          should eql('%d' => [19..20], '%ld' => [22..24])
      Fencer::Printf.fence(%|printf ("Preceding with blanks: %10d \n", 1977);|).
          should eql('%10d' => [32..35])
      Fencer::Printf.fence(%|printf ("Preceding with zeros: %010d \n", 1977);|).
          should eql('%010d' => [31..35])
      Fencer::Printf.fence(%|printf ("Some different radixes: %d %x %o %#x %#o \n", 100, 100, 100, 100, 100);|).
          should eql(
                     '%d'  => [33..34],
                     '%x'  => [36..37],
                     '%o'  => [39..40],
                     '%#x' => [42..44],
                     '%#o' => [46..48]
                 )
      Fencer::Printf.fence(%|printf ("floats: %4.2f %+.0e %E \n", 3.1416, 3.1416, 3.1416);|).
          should eql("%4.2f" => [17..21], "%+.0e" => [23..27], "%E" => [29..30])
      Fencer::Printf.fence(%|printf ("Width trick: %*d \n", 5, 10);|).
          should eql("%*d" => [22..24])
      Fencer::Printf.fence(%|printf ("%s \n", "A string");|).
          should eql("%s" => [9..10])
      Fencer::Printf.fence(%|printf("%1$d:%2$.*3$d:%4$.*3$d\n", hour, min, precision, sec);|).
          should eql('%1$d' => [8..11], '%2$.*3$d' => [13..20], '%4$.*3$d' => [22..29])
      Fencer::Printf.fence(%|printf("%10.10s", strperm (statbuf.st_mode));|).
          should eql("%10.10s"=>[8..14])
      Fencer::Printf.fence(%|printf(" %-8.8s", pwd->pw_name);|).
          should eql("%-8.8s"=>[9..14])
      Fencer::Printf.fence(%|printf("%9jd", (intmax_t) statbuf.st_size);|).
          should eql("%9jd"=>[8..11])
    end

    it "should handle %% tokens interspersed with positional tokens and adjacent to printf format strings" do
      # given a "%%" next to what happens to be a valid printf format string,
      # e.g., "%%ld", the '%%' should be fenced and the 'ld' treated as literal.

      # also, the only non-positional format specifier that can be interspersed
      # with positional format specifiers is '%%'

      Fencer::Printf.fence('My name is %2$s, and I am %1$u%% awesome. %%').
          should eql('%2$s' => [11..14], '%1$u' => [26..29], '%%' => [30..31, 42..43])
    end
  end
end
