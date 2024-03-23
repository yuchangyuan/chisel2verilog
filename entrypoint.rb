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
scala_src = []
jar_src = []
filelist_src = []

srcs.each do |s|
  scala_src << s if s.end_with?(".scala")
  jar_src   << s if s.end_with?(".jar")
  filelist_src << s if s.start_with?("@")
end

# ------------- compile
BASE = Pathname "/opt/java/lib"

chisel3_jar = Dir.glob(BASE + "*.jar")
plugin_jar = Dir.glob(BASE + "chisel-plugin*.jar")[0]

chisel3_jar.delete(plugin_jar)

classpath = chisel3_jar.join(':')

target_dir = Dir.mktmpdir("chisel2verilog")
at_exit { FileUtils.remove_entry(target_dir) }

compile_cmd = ["scalac", "-cp", classpath, "-Xplugin:#{plugin_jar}",
               "-d", target_dir] + scala_src + filelist_src


system(compile_cmd.join(" ")) or begin
  abort "compile fail"
end

# --------------- run
run_cmd = ["scala", "-cp", "#{classpath}:#{target_dir}",
           "chisel2verilog.run"] + args

system(run_cmd.join(" ")) or begin
  abort "run fail"
end
