#!/usr/bin/env ruby

require 'json'

raw = `cs resolve org.chipsalliance::chisel:5.0.0-RC2 -e 2.13`

out = {}

raw.split("\n").each do |line|
  pkg = line.split(":")

  (pkg[0] == "org.scala-lang") and begin
     puts "skip #{pkg}"
     next
  end

  name = "#{pkg[1]}-#{pkg[2]}.jar"
  url = "https://repo1.maven.org/maven2/#{pkg[0].split('.').join('/')}/#{pkg[1]}/#{pkg[2]}/#{name}"

  sha256 = `nix-prefetch-url #{url}`.strip

  out[name] = {
    "url"    => url,
    "sha256" => sha256
  }
end

File.open("deps.json", "w") do |f|
  f.puts(JSON.pretty_generate(out))
end
