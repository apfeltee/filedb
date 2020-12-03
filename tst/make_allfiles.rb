#!/usr/bin/ruby
# frozen_string_literal: true

require "optparse"
require "fileutils"
require "tempfile"
require "open3"
require "shellwords"
require "shell"
require "thread"
require "thwait"
require "sequel"
require_relative "./config.rb"


module Utils




  def self.cyg_to_win(path)
    #cygrx = /^\/cygdrive\/(.)/
    #if path.match(cygrx) then
    #  return path.gsub(cygrx, '\1:')
    #end
    cygprefix = "/cygdrive/"
    if path.start_with?(cygprefix) then
      tmp = path[cygprefix.length .. -1]
      drvletter = path[1]
      rest = path[1 .. -1]
      return (drvletter + ":" + (rest == nil ? "" : rest))
    end
    return path
  end

  def self.filesize(size)
    units = ['B', 'K', 'M', 'G', 'T', 'P', 'E']
    if size == 0 then
      return '0B'
    end
    exp = (Math.log(size) / Math.log(1024)).to_i
    if exp > 6 then
      exp = 6
    end
    return sprintf('%.1f%s', (size.to_f / (1024 ** exp)), units[exp])
  end

  def self.mkbackup(filepath, prefix: "bck.", verbose: false)
    fbase = File.basename(filepath)
    fdir = File.dirname(filepath)
    newbase = sprintf("%s%s", prefix, fbase)
    newpath = File.join(fdir, newbase)
    begin
      FileUtils.mv(filepath, newpath, verbose: verbose)
    rescue Errno::EBUSY => ex
      File.open(newpath, "wb") do |bckfh|
        File.open(filepath, "rb") do |infh|
          while true do
            chunk = infh.read(1024)
            if chunk == nil then
              return
            else
              bckfh.write(chunk)
            end
          end
        end
      end
    end
  end
end

def make_command(rootpath)
  cmd = ['find', '-path', rootpath, '-o']
  if not MKA_BADPATHS.empty? then
    cmd.push('(')
    MKA_BADPATHS.each_with_index do |bp, i|
      cmd.push('-ipath', './' + bp, '-prune')
      if (i+1) < MKA_BADPATHS.size then
        cmd.push('-o')
      end
    end
    cmd.push(')', '-o')
  end
  cmd.push('-type', 'f')
  #cmd.push('-printf', ['%p\n'].join(''))
  cmd.push("-print")
  return cmd
end

def walkfiles(rootpath, &cb)
  cmd = make_command(rootpath)
  Dir.chdir(rootpath) do
    Open3.popen3(*cmd) do |stdin, stdout, stderr, wait_thr|
      stdout.each do |line|
        line.scrub!
        line.strip!
        cb.call(line)
      end
    end
  end
end

class FileDB

  def initialize(rootpath, newrootpath, outputfile, filemode)
    @rootpath = rootpath
    @newrootpath = newrootpath
    @outputfile = outputfile
    @filemode = filemode
    #@outdb = File.open(outputfile, filemode)
    @outdb = Sequel.sqlite(@outputfile, :loggers => nil)
    @outdb.create_table? :items do
      primary_key :levelindex
      MKA_TABLAYOUT.each do |name, item|
        self.send(item.type, name)
      end
    end
  end

  def commit_fields(fieldvals, fpath, finfo)
    @outdb[MKA_TABLENAME].insert(fieldvals)
  end

  def get_custom_field_value(name, fpath, fst, rawline)
    case name
      when :filepath then
        return fpath
      when :sizehuman then
        return Utils.filesize(fst.size)
      else
        raise ArgumentError, sprintf("custom field %p is not implemented", name)
    end
  end


  def gather_fields(fpath, fst, rawline)
    missingfields = []
    fieldvals = {}
    MKA_TABLAYOUT.each do |name, item|
      if item.is_file_stat && fst.respond_to?(item.file_stat_member) then
        fieldvals[name] = fst.send(item.file_stat_member)
      else
        fieldvals[name] = get_custom_field_value(name, fpath, fst, rawline)
      end
    end
    commit_fields(fieldvals, fpath, fst)
  end

  def process_line(rawline)
    fpath = rawline.strip.gsub(MKA_ROOTREGEX, @newrootpath)
    missingfields = []
    begin
      fst = File.stat(fpath)
      gather_fields(fpath, fst, rawline)
    rescue => ex
      $stderr.printf("EXCEPTION: (%s) %s (line=%p)\n", ex.class.name, ex.message, rawline)
      $stderr.puts(ex.backtrace)
    end
  end

  def create_listing()
    counter = 0
    stagecnt = 0
    blockcnt = 0
    actuallyfinished = false
    $stderr.printf("create_listing: rootpath=%p, newrootpath=%p, outputfile=%p\n", @rootpath, @newrootpath, @outputfile)
    if File.file?(@outputfile) then
      Utils.mkbackup(@outputfile, verbose: true)
    end
   
    begin
      timestarted = Time.now
      walkfiles(@rootpath) do |file|
        lastpath = process_line(file)
        #outdb.flush
        counter += 1
        stagecnt += 1
        if (stagecnt == MKA_STAGEMAX) then
          blockcnt += 1
          stagecnt = 0
          timedif = Time.now - timestarted
          timefmt = Time.at(timedif.to_i.abs).utc.strftime("%H:%M:%S")
          $stderr.printf("completed %d blocks (%d files; time passed: %s) lastseen: %p\n", blockcnt, counter, timefmt, lastpath)
        end
      end
      actuallyfinished = true
    ensure
      #outdb.close
      $stderr.printf("finished -- found %d files!\n", counter)
      if actuallyfinished then
        system("messagebox", "done creating #{outputfile.dump}!")
      end
    end
  end
end

begin
  quickupdate = false
  actuallydoit = false
  rootpath = MKA_ROOTPATH
  newrootpath = MKA_NEWROOTPATH
  outputfile = MKA_OUTPUTFILE
  filemode = "wb"
  lastdir = nil
  prs = OptionParser.new{|prs|
    prs.banner = ""
    prs.banner += "usage: #$0 [-q] [-f] [-o<path>] [<rootpath>]\n"
    prs.banner += "default rootpath is #{MKA_ROOTPATH.dump}\n"
    prs.banner += "\n"
    prs.on("-q", "--quick", "quick update: remove non-existing files from #{MKA_OUTPUTFILE.dump}"){|_|
      quickupdate = true
    }
    prs.on("-f", "--force", "force creation of listing"){|_|
      actuallydoit = true
    }
    prs.on("-o<path>", "--outputfile=<path>", "set output file to <path>. default is #{MKA_OUTPUTFILE.dump}"){|v|
      outputfile = v
    }
    prs.on("-l<path>", "--lastdir=<path>", "continue from last path"){|v|
      lastdir = v
    }
  }
  prs.parse!
  if quickupdate then
    $stderr.printf("updating is no longer implemented. sorry\n")
    exit(1)
  else
    if actuallydoit then
      if not ARGV.empty? then
        rootpath = ARGV.shift
        if not File.directory?(rootpath) then
          $stderr.printf("supplied root path %p is not a directory!", rootpath)
          exit(1)
        end
      end
      FileDB.new(rootpath, newrootpath, outputfile, filemode).create_listing
    else
      $stderr.puts([
        "***---------------------------------------------------***",
        "*** WARNING:                                          ***",
        "*** refusing to create listing without the '-f' flag! ***",
        "***---------------------------------------------------***",
      ].join("\n"))
      $stderr.puts(prs.help)
      exit(1)
    end
  end
end

