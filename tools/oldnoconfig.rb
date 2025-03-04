require 'pty'
require 'irb'

# kernel 2.6.11 does not provide `make oldnoconfig`
# so I write this simple script to do that.

domake_path=ARGV[0]
linux_path=ARGV[1]
logfile_path=ARGV[2]

unless test 'f', domake_path
  raise "[E] invalid domake path #{domake_path}"
end

unless test 'f', "#{linux_path}/Makefile"
  raise "[E] invalid kernel path #{linux_path}"
end

begin
  logfile = File.open logfile_path, "w"
rescue Errno::ENOENT
  raise "[E] invalid log file path #{logfile_path}"
end

Dir.chdir linux_path
pty_read, pty_write, pid = PTY.spawn("#{domake_path} oldconfig")

options_no=[]
options_yes=[]
options_other=[]
choices=[]
history=""

loop do
  begin
    # Need to read text chunk by chunk 
    # because in the middle of process we'll be presented some questions.
    res = pty_read.read_nonblock(1024)

    # Redirect what reads from PTY to stdout to show the process.
    puts res
    history += res
    if res.end_with? '(NEW) '
      if index = res.rindex("\n")
        lastline = res[index..].strip
      else
        lastline = res.strip
      end
      # 
      # When encountering a new symbol
      # the last line has the following patterns
      # 
      # 1. Ask for yes or no
      #    We answer no
      # ------------------------------------------------------------------------------
      # Select only drivers expected to compile cleanly (CLEAN_COMPILE) [Y/n/?] (NEW)
      # ----------------------------------------------- --------------- -------
      #                prompt                             symbol name   options
      #
      # 2. Ask for inputing something
      #    We just print a new line into `pty_write to select the default.
      #    The same as type ENTER on keyboard when doing so interactively in terminal.
      # 
      # Local version - append to kernel release (LOCALVERSION) [] (NEW)
      # ---------------------------------------- -------------- --
      #
      # Kernel log buffer size (16 => 64KB, 17 => 128KB) (LOG_BUF_SHIFT) [14] (NEW) 
      # ------------------------------------------------ --------------- ----
      #
      unless index = (lastline =~ /(\(\w*?\)) \[(.*?)\] \(NEW\)/)
        raise '[E] cannot match last line of a new symbol'
      end
      prompt = lastline[..index]
      symbol, options = $1, $2
      logfile.write "#{symbol} [#{$2}]"
      if options.upcase.include? "N"
        pty_write.puts 'n'
        logfile.write " n\n"
        options_no.push [res, prompt, symbol, options]
      elsif options.upcase.include? "Y"
        pty_write.puts 'y'
        logfile.write " y\n"
        options_yes.push [res, prompt, symbol, options]
      else
        pty_write.puts
        logfile.write " #{$2}\n"
        options_other.push [res, prompt, symbol, options]
      end
    elsif res.end_with? ']: '
      # See comments at the end of file.
      # binding.irb
      pty_write.puts
      choices.push [res]
    end
  rescue IO::WaitReadable
    IO.select [pty_read]
    retry
  rescue Errno::EIO
    break
  end
end

# binding.irb
logfile.close

#
# When encountering a choice, the following text shows in the terminal
# Just output a new line to pty_write, the same as you press Enter on keyboard
# to select the default choice.
# 
# Subarchitecture Type
# > 1. PC-compatible (X86_PC) (NEW)
#   2. AMD Elan (X86_ELAN) (NEW)
#   3. Voyager (NCR) (X86_VOYAGER) (NEW)
#   4. NUMAQ (IBM/Sequent) (X86_NUMAQ) (NEW)
#   5. SGI 320/540 (Visual Workstation) (X86_VISWS) (NEW)
# choice[1-5]:
#