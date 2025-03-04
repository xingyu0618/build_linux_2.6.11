compdb_path = ARGV[0]

unless test 'f', compdb_path
  raise "[E] invalid compile_commands.json path #{compdb_path}"
end

require 'json'

json = JSON.load_file compdb_path

# [
#   {
#     "arguments": [], // arguments to gcc
#     "directory": [], // working directory where the compiling occurred
#     "file":"",       // the file being compiled
#     "output": ""     // the output file
#   }
# ]
# 
# What we did here is to group "file" by their directory names
# to see which directory owns the most files.

json.map {
  _1['file']             # extract files
}.group_by {
  File.dirname _1        # group by directoriy names
}.sort_by { |dir, files|
  files.size             # sort by number of files
}.reverse.map { |dir, files|
  "#{dir} #{files.size}" # directories that have most files come first
}.join("\n").tap{
  puts _1                # output the result  
}
