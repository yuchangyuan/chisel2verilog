#!/usr/bin/env ruby

require 'pathname'
require 'tmpdir'

# ----------- split src & arg
args = []
srcs = []

idx = ARGV.find_index("--")

if idx then
  srcs = ARGV.take(idx)
  args = ARGV.drop(idx + 1)
else
  srcs = ARGV
end

# -------------- split scala src & jar
src_list = []
cp_list = []

psrc_list = [] # src need precompile

opt_list = []

def is_valid_src(s)
  s.end_with?(".scala") || s.end_with?(".java") || s.start_with?("@")
end

srcs.each do |s|
  if s.start_with?("+")
    s1 = s.sub(/^\+/, '')
    psrc_list << s1 if is_valid_src(s1)
  elsif is_valid_src(s)
    src_list << s
  elsif s.end_with?(".jar")
    cp_list << s
  else
    # we assume no option:
    # 1. start with '+'
    # 2. start with '@', end with '.scala', '.java' or '.jar'no option:
    opt_list << s
  end
end

# ------------- compile
BASE = Pathname "/opt/java/lib"

chisel3_jar = Dir.glob(BASE + "*.jar")
plugin_jar = Dir.glob(BASE + "chisel-plugin*.jar")[0]

chisel3_jar.delete(plugin_jar)

classpath = (chisel3_jar + cp_list).join(':')

target_dir = Dir.mktmpdir("chisel2verilog")
at_exit { FileUtils.remove_entry(target_dir) }

# do precompile if necessary
unless psrc_list.empty?
  precompile_cmd = ["scalac", "-cp", classpath, "-Xplugin:#{plugin_jar}",
                    "-d", target_dir] + opt_list + psrc_list

  #pp precompile_cmd
  system(precompile_cmd.join(" ")) or begin
    abort "precompile fail"
  end

  classpath += ":#{target_dir}"
end

compile_cmd = ["scalac", "-cp", classpath, "-Xplugin:#{plugin_jar}",
               "-d", target_dir] + opt_list + src_list

#pp compile_cmd
system(compile_cmd.join(" ")) or begin
  abort "compile fail"
end

# --------------- run
run_cmd = ["scala", "-cp", "#{classpath}:#{target_dir}",
           "chisel2verilog.run"] + args

system(run_cmd.join(" ")) or begin
  abort "run fail"
end
