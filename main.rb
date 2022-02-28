require 'git'
require 'optparse'
require 'pathname'

DEFAULT_DIR = '.cache'

options = {}
OptionParser.new do |parser|
  parser.banner = "Usage: example.rb [options]"

  parser.on("-cURL", "--clone=URL", "Clone repo. Additionally, specify where to clone with -p or --path (by default will be cloned to '.cache') and the name of ") do |arg|
    options[:url] = arg
  end

  parser.on("-pPATH", "--path=PATH", "Open already existing repo in that PATH or specify to which folder to clone a repo.") do |arg|
    options[:path] = arg
  end

  parser.on("-nNAME", "--name=NAME", "Local name of the repo") do |arg|
    options[:name] = arg
  end
end.parse!

p options

unless options[:path]
  options[:path] = DEFAULT_DIR
end

unless options[:name]
  is_path = false
  if (options[:url])
    p options[:name] = options[:url].split('/')[-1][..-5]
  else  
    options[:name] = (0...8).map { (97 + rand(26)).chr }.join
  end
end

if (options[:url])
  repo = Git.clone(options[:url], options[:name], :path => options[:path])
elsif (is_path)
  repo = Git.open(options[:path])
else
  puts "No repo specified"
  exit
end


logs = repo.log

from = 0
till = 20000

logs[from..till].each do |log|
  p log.message
end
# p logs.last