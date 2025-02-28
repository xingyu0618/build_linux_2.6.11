require 'pty'
require 'irb'

# `rm -f .config .config.old`
# `cp .config.oldx .config`

r,w,p = PTY.spawn('../domake oldconfig')
fp = File.open "conf_result", "w"
loop do
  begin
    res = r.read_nonblock(1024)
    break unless res and res.size>0
    puts res
    if res.end_with? '(NEW) '
      raise "** ERROR" unless res =~ /(\(\w*?\)) \[(.*?)\] \(NEW\) $/
      puts "=== #{$1} ==="
      fp.write "#{$1} [#{$2}]"
      if $2.upcase.include? "N"
        w.puts 'n'
        fp.write " n\n"
      elsif $2.upcase.include? "Y"
        w.puts 'y'
        fp.write " y\n"
      else
        w.puts
        fp.write " #{$2}\n"
      end
    elsif res.end_with? ']: '
      puts "=== chocie ==="
      w.puts
    elsif res =~ /\[(.*?)\] \(NEW\)/
      puts "===2 #{$1} ==="
      w.puts
    end
  rescue IO::WaitReadable
    IO.select [r]
    retry
  rescue Errno::EIO
    puts "=== EOF pty ==="
    break
  end
end

fp.close