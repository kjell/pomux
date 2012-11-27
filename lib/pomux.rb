# encoding: utf-8
%w(rubygems bundler yaml).each {|l| require l }
Bundler.require(:test) if defined?(POMUX_TESTING)

class Pomux
  def path
    File.expand_path("~/.pomux")
  end

  def info
    @info ||= YAML::load(File.read(path))
  end

  def save
    File::write(path, YAML::dump(info))
  end

  def start(slip=0)
    return if started?
    info['started'] ||= Time.now - slip*60
    save
    job = elapsed > 5 ? 'good job' : 'chill out!'
    notify "#{elapsed.to_i} minute break, #{job}."
    Process.spawn("killall Mail")
    nil
  end

  def method_missing(m, *args)
    if slip = m[/minus_(\d+)/, 1]
      start(slip.to_i)
    else
      super
    end
  end

  def respond_to_missing(method, include_private=false)
    method =~ /minus_(\d+)/
  end

  def elapsed
    (Time.now - info['last'])/60
  end

  def started?
    !!info['started']
  end

  def ending
    info['started'] + 25*60
  end

  def started
    info['started']
  end

  def ended
    info['last']
  end

  def poll
    if started?
      if done?
        done!
        0
      else
        remaining.ceil
      end
    end
  end

  def done?
    remaining <= 0
  end

  def done!
    return unless started?
    info['started'] = nil
    info['count'] += 1
    info['last'] = Time.now
    save
    Process.spawn "~/bin/itunes_stop_after_current_track.rb"
    notify 'done!', :sticky => true
  end

  def notify(message, opts={})
    Process.spawn "/usr/local/bin/growlnotify pomux #{'-s' if opts[:sticky]} -m '#{message}'"
    Process.spawn "tmux refresh-client -S -t $(tmux list-clients -F '\#{client_tty}')"
    message
  end

  def remaining
    (ending - Time.now) / 60
  end

  def progress
    if started?
      "#{poll}m"
    elsif (Time.now - ended) <= 5*60
      %w(⇈  ᚚ  ⇶).sample
    else
      # ⦿ ① ② ③ ④ ⑤ ⑥ ⑦ ⑧ ⑨ ⑩ ⑪ ⑫ ⑬ ⑭ ⑮ ⑯ ⑰
      # ⓵ ⓶ ⓷ ⓸ ⓹ ⓺ ⓻ ⓼ ⓽ ⓾
      # ❶ ❷ ❸ ❹ ❺ ❻ ❼ ❽ ❾ ❿ ➀ ➁ ➂ ➃ ➄ ➅ ➆ ➇ ➈ ➉
      # I could also try braille dots, unicode table 10241 on
      counters = %w(⦿ ➊ ➋ ➌ ➍ ➎ ➏ ➐ ➑ ➒ ➓)
      counters[count]
    end
  end

  def report
    progress
  end

  def reset
    return unless started? || count > 0
    output = "Resetting from #{info['count']}."
    info['count'] = 0
    save
    output
  end

  def count(silent=true)
    info['count'].tap {|c| puts c unless silent }
  end

  def abort
    info['started'] = nil
    info['last'] = Time.now
    save
    notify 'Aborted'
  end
  alias_method :stop, :abort
  alias_method :quit, :abort

  def growl
    notify progress
  end

  def log
    @log_string = loggers.inject("") {|log, logger| log << logger.new(self, log).log}
    reset
    info['last'] = Time.now
    save
    @log_string
  end

  def loggers
    @loggers ||= [PomuxLogger, GitLogger, DayOneLogger]
  end

  def log_string
    @log_string
  end
end

class PomuxLogger
  attr_accessor :pomux, :string

  def initialize(pomux, string)
    @pomux = pomux
    @string = string
  end

  def minutes;  pomux.count*30; end
  def elapsed; pomux.elapsed; end

  def log
    "#{minutes}m + #{elapsed}m #{Dir.pwd[/\/(\w+)$/, 1]}\n\n---\n\n"
  end
end

class GitLogger < PomuxLogger
  def log
    `git log --author="$(whoami)" --since '#{(minutes + elapsed).to_i} minutes ago'`
  end
end

class DayOneLogger < PomuxLogger
  def log
    Process.spawn %[open -a "Day One"]
    Process.spawn %[echo "#{string}" | pbcopy && open ~/bin/day-one-activate-paste.app]
    ''
  end
end
