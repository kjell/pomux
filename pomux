#!/usr/bin/env ruby-local-exec
# encoding: utf-8
require 'yaml'

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
    spawn("killall Mail")
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
      else
        remaining.to_i + 1
      end
    end
  rescue
    notify $!
  end

  def done?
    remaining <= 0
  end

  def done!
    info['started'] = nil
    info['count'] += 1
    info['last'] = Time.now
    save
    # `~/bin/itunes_stop_after_current_track.rb` # Needs to fork out probably
    spawn "~/bin/itunes_stop_after_current_track.rb"
    notify 'done!', :sticky => true
  end

  def notify(message, opts={})
    spawn "/usr/local/bin/growlnotify pomux #{'-s' if opts[:sticky]} -m '#{message}'"
    spawn "tmux refresh-client -S -t $(tmux list-clients -F '\#{client_tty}')"
    message
  end

  def remaining
    (ending - Time.now) / 60
  end

  def to_s
    if started?
      "#{poll}m"
    elsif (Time.now - ended) <= 5*60
      ['⇈', ' ᚚ ', '⇶'].sample
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
    to_s
  ensure
    File::write(File.expand_path('~/.pomux_report'), to_s)
  end

  def reset
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
    notify to_s
  end

  def log
    c = count
    "#{c*30}m + #{elapsed}m #{Dir.pwd[/\/(\w+)$/, 1]}\n\n---\n\n".tap do |s|
      s << `git log --author="$(whoami)" --since '#{(c*30 + elapsed).to_i} minutes ago'`
      spawn %[echo "#{s}" | pbcopy && open ~/bin/day-one-activate-paste.app]
      reset
    end
    info['last'] = Time.now
    save
  end
end

Pomux.new.tap do |p|
  !ARGV.empty? ? ARGV.map {|a| print p.send(a)} : p.growl
end
