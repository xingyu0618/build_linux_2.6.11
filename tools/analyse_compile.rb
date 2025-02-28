path = ARGV[0]
pp ARGV
pp $*
unless test 'f', path
  raise "** NOENT #{path}"
end

require 'json'

js = JSON.load_file path

js.map {
  x = _1['file']
}.group_by {
  File.dirname _1
}.sort_by { |dir, child|
  child.size
}.reverse.map { |dir,child|
  "#{dir} #{child.size}"
}.join("\n").tap{
  puts _1
  # File.write "compile_result", _1
}