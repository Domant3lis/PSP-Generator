#!/usr/bin/env ruby

require './psp'
require './parse.rb'
require 'optparse'
require 'csv2md'
require 'csv_shaper'
require 'time'

@options = {
	repopath: nil,
	# since_commit: nil,
	# till_commit: nil,
	# markdown_fileout: nil,
	# markdown_stdout: nil,
	csv_fileout: nil,
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

	parser.on('--tags TAGS', 'Specify which commits with tags to include') do |arg|
		@options[:tags] = arg.split(/; */)
	end

	parser.on('--exclude-commits COMMITS', 'Specify which commits to exclude, follows this syntax: --exclude-commits \'1234567890; 1234567890\'') do |arg|
		@options[:exclude_commits] = arg.split(/; */)
	end

	parser.on('--include-commits COMMITS', 'Specify which commits to include, follows this syntax: --include-commits \'1234567890; 1234567890\'') do |arg|
		@options[:include_commits] = arg.split(/; */)
	end

	parser.on('--syntax SYNTAX', 'Specify which syntax (psp or lff) (psp by default) to use to parse commits') do |arg|
		@options[:syntax] = arg.downcase
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

repo = PSP.new(@options[:repopath])

case @options[:syntax]
when 'psp'
	repo = psp(repo)
	time_sep = ' '
when 'lff'
	time_sep = ';'
	repo = lff(repo)
else
	puts "#{options[:syntax]} not supported"
	exit
end

# puts repo.data

if @options[:exclude_commits]
	repo.filter_commits do |commit|
		@options[:exclude_commits].none? { |ec| commit[:itself].sha[...ec.size] == ec }
	end
end

repo.filter_commits do |commit|
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

	if @options[:syntax] == 'lff'
		reg = /lff: /mi
		includes &=	reg.match(commit[:itself].message)
	end

	# Todo exclude / include commiters
	# includes = commit[:itself].commiters.any? @options[:commiters]

	includes
end

repo.on('Till') do |commit|
	begin
		commit = date_parse(commit, 'Till', sep: time_sep)
	rescue StandardError
		puts("EXP: Failed to parse field 'Till' in commit #{commit['itself']}: #{commit['Till']}")
	end

	commit
end

repo.on('From') do |commit|
	begin
		commit = date_parse(commit, 'From', sep: time_sep)
		commit['Overall'] = (commit['Date'].to_i - commit['From'].to_i) / 60
	rescue StandardError
		puts("EXP: Failed to parse field 'From' in commit #{commit['itself']}: #{commit['From']}")
	end

	commit
end

repo.on('From', 'Interruptions') do |commit|
	begin
		time = commit['Date'].to_i
		time -= commit['From'].to_i

		interruptions = commit['Interruptions'].split(';')

		ints = []

		interruptions.each do |int|
			temp = int.split('(')[0].strip

			case temp
			when /[0-9]+:[0-9]+/
				temp = Time.strptime("1970-01-01 #{temp} +0000", "%Y-%m-%d %k:%M %z")
				ints.push(temp)
			when /[0-9]+/
				temp = Time.strptime("1970-01-01 0:#{temp} +0000", "%Y-%m-%d %k:%M %z")
				ints.push(temp)
			else
				puts "Failed to parse an interruption from commit '#{commit[:itself].sha}' `#{int}`"
			end
		end

		ints.each do |int|
			time -= int.to_i
		end

		commit['Overall'] = time / 60
	rescue StandardError
		puts("EXP: Failed to parse fields 'From' and 'Interruptions' in commit #{commit['itself']}: #{commit['From']}, #{commit['Interruptions']}")
	end
	commit
end

# Some string formatting
repo.on('Date') do |commit|
	commit['Till'] = commit['Date'].to_s[11..15]
	commit
end

repo.on_cell('Changes') do |cell|
	cell = "`-#{cell.deletions.to_int} +#{cell.lines.to_int} ~#{cell.insertions.to_int}`"
	cell
end

repo.on_cell('Date') do |cell|
	cell = cell.to_s[5..10]
	cell
end

repo.on_cell('From') do |cell|
	if cell.instance_of?(Time)
		cell = cell.to_s[11..15]
	end
	cell
end

repo.on_all_cells do |cell|
	if cell.instance_of?(String)
		cell = cell.split(/\n/).join(' ')
			.split(/\t/).join(' ')
	end

	cell
end

data = repo.data

data.map! do |commit|
	commit.delete(:itself)
	commit
end

# puts data

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

csv_string = repo.to_csv(exclude: ['Tag'], preset: default_preset, col_sep: "\t")

if @options[:csv_stdout]
	puts(csv_string)
end

if @options[:csv_fileout]
	file = File.new(@options[:csv_fileout], 'w')
	file.syswrite(csv_string)
end
