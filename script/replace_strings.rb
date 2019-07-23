# Using an imported list of strings from a CSV, this script can replace strings.

arguments = ARGV

file_name = arguments[0]
dry_run = arguments[1] || true

puts "Filename: #{file_name}"
puts "Dry run: #{dry_run}"

