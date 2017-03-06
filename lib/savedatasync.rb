require "savedatasync/version"
require "savedatasync/usage"
require "fileutils"
require 'optparse'

module Savedatasync
  class Command < Struct.new(
    :sub_command, :force, :title, :remote_dir_path, :local_path, :remote_filename
  )

    def self.from_argv(argv)
      com = extract_argv(new, argv)
      com.title ||= File.basename(File.dirname(com.local_path))
      com.remote_dir_path ||= File.expand_path(default_remote_dir)
      com.remote_filename ||= File.basename(com.local_path)
      return com
    end

    def self.default_remote_dir
      ENV['sdsync_remote_dir'] || "#{Dir.home}/Dropbox/sdsync"
    end

    def self.extract_argv(com, argv)
      opt_parser = OptionParser.new do |parse|
        parse.banner = Savedatasync::USAGE
        desc = 'force to execute even if there is an existing file'
        parse.on('--force', desc) do
          com.force = true
        end
        desc = 'specify title. basename(dirname(savedata-file)) is used as default'
        parse.on('--title=TITLE', desc) do |title|
          com.title = title
        end
        desc = "specify the path of remote directory. ENV['sdsync_remote_dir'] or ~/Dropbox/sdsync is used as default"
        parse.on('--remote=PATH', desc) do |path|
          com.remote_dir_path = path
        end
      end
      sub_command, *args_without_option = opt_parser.parse(argv)
      unless ['get', 'put', 'cut', 'status'].include?(sub_command)
        STDERR.puts "invalid subcommand #{sub_command}"
        STDERR.puts opt_parser.help
        exit(1)
      end
      unless 1 <= args_without_option.size && args_without_option.size <= 2
        STDERR.puts "invalid length of arguments"
        STDERR.puts opt_parser.help
        print_usage
        exit(1)
      end
      com.sub_command = sub_command
      com.local_path = File.expand_path(args_without_option[0])
      com.remote_filename = args_without_option[1]
      return com
    rescue OptionParser::InvalidOption => error
      STDERR.puts error.message
      print_usage
      exit(1)
    end

    def self.help(opt_parser)
      STDERR.puts
    end

    def run
      op = Operator.new(title, force, remote_dir_path)
      case sub_command
      when 'put'
        op.put(local_path, remote_filename)
      when 'get'
        op.get(local_path, remote_filename)
      when 'cut'
        op.cut(local_path, remote_filename)
      when 'status'
        op.status(local_path, remote_filename)
      end
    rescue Operator::Error => err
      STDERR.puts err.message
      exit(1)
    end
  end

  class Operator
    Error = Class.new(StandardError)

    def initialize(title, force, remote_dir_path)
      @title = title
      @force = force
      @remote_dir_path = remote_dir_path
      title_dir_path = File.expand_path(@remote_dir_path + '/' + @title)
      unless File.directory?(@remote_dir_path)
        raise Error.new("remote dir #{@remote_dir_path} does not exist")
      end
      FileUtils.mkdir(title_dir_path) unless File.exist?(title_dir_path)
    end

    def put(local_path, remote_filename)
      remote_path = construct_remote_path(local_path, remote_filename)
      lstatus = local_status(local_path, remote_path)
      rstatus = remote_status(remote_path)
      case lstatus
      when :entity
        if rstatus == :entity
          unless @force
            raise Error.new("remote file '#{remote_path}' exists. use -f to force")
          end
          FileUtils.rm_r(remote_path)
        end
        FileUtils.mv(local_path, remote_path)
        FileUtils.symlink(remote_path, local_path)
        return true
      when :empty
        raise Error.new("local file '#{local_path}' is empty")
      when :valid_link
        if rstatus == :empty
          raise Error.new("local file '#{local_path}' is broken link. remove it to continue")
        end
        return true
      when :invalid_link
        raise Error.new("local file '#{local_path} is broken link. remove it to continue")
      end
    end

    def get(local_path, remote_filename)
      remote_path = construct_remote_path(local_path, remote_filename)
      lstatus = local_status(local_path, remote_path)
      rstatus = remote_status(remote_path)
      case lstatus
      when :entity
        if rstatus == :empty
          raise Error.new("remote file '#{remote_path}' is empty")
        end
        unless @force
          raise Error.new("local file '#{local_path}' exists. use -f to force")
        end
        FileUtils.rm_r(local_path)
        FileUtils.symlink(remote_path, local_path)
        return true
      when :empty
        if rstatus == :empty
          raise Error.new("remote file '#{remote_path}' is empty")
        end
        FileUtils.symlink(remote_path, local_path)
        return true
      when :valid_link
        if rstatus == :empty
          raise Error.new("local file '#{local_path}' is broken link. remove it to continue")
        end
        return true
      when :invalid_link
        raise Error.new("local file '#{local_path} is broken link. remove it to continue")
      end
    end

    def cut(local_path, remote_filename)
      remote_path = construct_remote_path(local_path, remote_filename)
      lstatus = local_status(local_path, remote_path)
      rstatus = remote_status(remote_path)
      unless lstatus == :valid_link && rstatus == :entity
        raise Error.new("cannot cut un-synced file")
      end
      FileUtils.rm_r(local_path)
      FileUtils.cp_r(remote_path, local_path)
      return true
    end

    def status(local_path, remote_filename)
      remote_path = construct_remote_path(local_path, remote_filename)
      lstatus = local_status(local_path, remote_path)
      rstatus = remote_status(remote_path)
      STDERR.puts "[#{@title}] #{local_path} (#{lstatus}) <==> #{remote_path} (#{rstatus})"
      return true
    end

    private

    def local_status(local_path, remote_path)
      if File.symlink?(local_path)
        File.readlink(local_path) == remote_path ? :valid_link : :invalid_link
      else
        File.exist?(local_path) ? :entity : :empty
      end
    end

    def remote_status(remote_path)
      File.exist?(remote_path) ? :entity : :empty
    end

    def construct_remote_path(local_path, remote_filename)
      File.expand_path("#{@remote_dir_path}/#{@title}/#{remote_filename}")
    end
  end
end
