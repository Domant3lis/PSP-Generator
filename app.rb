#!/usr/bin/env ruby

require 'optparse'
require 'csv2md'
require './psp'
require 'csv_shaper'
require 'time'

@options = {
	repopath: nil,
	# since_commit: nil,
	# till_commit: nil,
	# markdown_fileout: nil,
	csv_fileout: nil,
	# markdown_stdout: nil,
	csv_stdout: nil,
	csv_filein: nil,
	tags: nil,
	syntax: 'psp'
}

OptionParser.new do |parser|
	parser.banner = 'Usage: psp.rb [options]'

	parser.on('-rPATH', '--repo PATH', 'Open local repo in PATH') do |arg|
		@options[:repopath] = arg
	end

	parser.on('-cFILEPATH', '--csv FILEPATH', 'Specify where to export the csv file') do |arg|
		@options[:csv_fileout] = arg
	end

	parser.on('--display-csv', 'Displays cvs output to stdout') do
		@options[:csv_stdout] = true
	end

	# parser.on('--syntax=SYNTAX', 'Choose in which mode to parse your commits, supported: psp, WIP: lff') do |arg|
	# 	@options[:syntax] = arg
	# end

	parser.on('--tags TAGS', 'Specify which commits with tags to include') do |arg|
		@options[:tags] = arg.split(/; */)
	end

	parser.on('--exclude-commits COMMITS', 'Specify which commits to exclude, follows this syntax: --exclude-commits \'1234567890; 1234567890\'') do |arg|
		@options[:exclude_commits] = arg.split(/; */)
	end

	parser.on('--include-commits COMMITS', 'Specify which commits to include, follows this syntax: --include-commits \'1234567890; 1234567890\'') do |arg|
		@options[:include_commits] = arg.split(/; */)
	end

	# parser.on('--since-commit=SINCE', Integer, 'Specify from which commit to generate, default is 0 (i.e. newest)') do |arg|
	# 	@options[:since_commit] = arg
	# end

	# parser.on('--till-commit=TILL', 'Specify till which commit to generate, default is 100 (i.e. till newest 100th commit)') do |arg|
	# 	@options[:till_commit] = arg
	# end

	# parser.on('--csv-in=FILEPATH', 'TODO') do |arg|
	# 	@options[:csv_filein] = arg
	# end

	# parser.on('-mFILEPATH', '--markdown=FILEPATH', 'Specify where to export the markdown file') do |arg|
	# 	@options[:markdown_fileout] = arg
	# end

	# parser.on('--display-markdown', 'Displays markdown output to stdout') do
	# 	@options[:markdown_stdout] = true
	# end
end.parse!

psp = PSP.new(@options[:repopath])

psp.read_commits do |log|
	commit = {}

	commit_msg = log.message.split(/-+ *PSP *-+/)
	commit['Details'] = commit_msg[0].split(/\n/).join(' ').split(/\t/).join(' ')

	if commit_msg[1]

		fields = commit_msg[1].split("\n")

		fields[1..].each do |field|
			temp = field.split(':')

			key = temp[0]
			value = temp[1..].join(':')

			commit[key] = value
		end
	end

	commit
end

if @options[:exclude_commits]
	psp.filter_commits do |commit|
		@options[:exclude_commits].none? { |ec| commit[:itself].sha[...ec.size] == ec }
	end
end

psp.filter_commits do |commit|
	includes = true
	if @options[:tags]
		includes = false
		includes ||= @options[:tags].any? { |t| commit['Tag']&.include? t }
	end

	if @options[:include_commits] && !includes
		includes ||= @options[:include_commits].any? do |ic|
			commit[:itself].sha[...ic.size] == ic
		end
	end

	# Todo exclude / include commiters
	# includes = commit[:itself].commiters.any? @options[:commiters]
	
	includes
end

psp.on('Changes') do |commit|
	commit['Changes'] = "`-#{commit['Changes'].deletions.to_int} +#{commit['Changes'].lines.to_int} ~#{commit['Changes'].insertions.to_int}`"
	commit
end

def date_parse(commit, key)
	case commit[key]
	when / *@prev_commit/
		temp = commit[:itself].parent.committer_date

		# Parses full date and time with timezone
	when / *[0-9]+-[0-9]+-[0-9]+ [0-9]+:[0-9]+ [+-][0-9]:[0-9]+:[0-9]+/
		temp = Time.strptime(commit[key], '%Y-%m-%d %H:%M %::z')

	when / *[0-9]+-[0-9]+-[0-9]+ [0-9]+:[0-9]+ [+-][0-9]+:[0-9]+/
		temp = Time.strptime(commit[key], '%Y-%m-%d %H:%M %:z')

	when / *[0-9]+-[0-9]+-[0-9]+ [0-9]+:[0-9]+ [+-][0-9]+/
		temp = Time.strptime(commit[key], '%Y-%m-%d %H:%M %z')

	# Parses full date and time
	when / *[0-9]+-[0-9]+-[0-9]+ [0-9]+:[0-9]+/
		temp = Time.strptime(commit[key], '%Y-%m-%d %H:%M')

		temp = Time.new(temp.year, temp.mon, temp.day, temp.hour, temp.min, commit['Date'].zone)
	# Parses only hours and minutes
	when / *[0-9]+:[0-9]+/
		temp = Time.strptime(commit[key], ' %H:%M')

		temp = Time.new(commit['Date'].year, commit['Date'].mon, commit['Date'].day, temp.hour, temp.min, commit['Date'].zone)
	else
		temp = commit[key]
		puts("WARN: Failed to parse field 'From' in commit #{commit['itself']}: #{commit[key]}")
	end

	commit[key] = temp
	commit
end

psp.on('Till') do |commit|
	begin
		commit = date_parse(commit, 'Till')
	rescue StandardError
		puts("Failed to parse field 'Till' in commit #{commit['itself']}: #{commit['Till']}")
	end

	commit
end

psp.on('From') do |commit|
	begin
		commit = date_parse(commit, 'From')
		commit['Overall'] = (commit['Date'].to_i - commit['From'].to_i) / 60
	rescue StandardError
		puts("EXP: Failed to parse field 'From' in commit #{commit['itself']}: #{commit['From']}")
	end

	commit
end

psp.on('From', 'Interruptions') do |commit|
	begin
		time = commit['Date'].to_i
		time -= commit['From'].to_i

		interruptions = commit['Interruptions'].split(';')

		ints = []

		interruptions.each do |int|
			int_ = int.split('(')
			begin
				# Parses "%M"
				ints.push(Integer(int_[0]) * 60)
			rescue StandardError
				begin
					# Parses "%H:%M"
					ints.push(Integer(int_.split(':')[0] * 60 * 60, 60 * Integer(int_.split(':')[1])))
				rescue StandardError
					puts "Failed to parse an interruption from commit '#{row[:itself].sha}' `#{int}`"
					next
				end
			end
		end

		ints.each do |int|
			time -= int.to_i
		end

		commit['Overall'] = time / 60
	rescue StandardError
		puts("Failed to parse fields 'From' and 'Interruptions' in commit #{commit['itself']}: #{commit['From']}, #{commit['Interruptions']}")
	end
	commit
end

# Some string formatting
psp.on('Date') do |commit|
	commit['Till'] = commit['Date'].to_s[11..15]
	commit
end

psp.on('Date') do |commit|
	commit['Date'] = commit['Date'].to_s[5..10]
	commit
end

psp.on('From') do |commit|
	commit['From'] = commit['From'].to_s[11..15]
	commit
end

default_preset = Set[
	'Date',
	'From',
	'Till',
	'Interruptions',
	'Overall',
	'Action',
	'Details',
	'Changes',
]

csv_string = psp.to_csv(exclude: ['Tag'], preset: default_preset, col_sep: "\t")

if @options[:csv_stdout]
	puts(csv_string)
end

if @options[:csv_fileout]
	file = File.new(@options[:csv_fileout], 'w')
	file.syswrite(csv_string)
end
