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
	syntax: 'psp',
}

OptionParser.new do |parser|
	parser.banner = 'Usage: psp.rb [options]'

	parser.on('-rPATH', '--repo=PATH', 'Open local repo in that PATH') do |arg|
		@options[:repopath] = arg
	end

	parser.on('-cFILEPATH', '--csv=FILEPATH', 'Specify where to export the csv file') do |arg|
		@options[:csv_fileout] = arg
	end

	parser.on('--display-csv', 'Displays cvs output to stdout') do
		@options[:csv_stdout] = true
	end

	parser.on('--syntax=SYNTAX', 'Choose in which mode to parse your commits, supported: psp, WIP: lff') do |arg|
		@options[:syntax] = arg
	end

	parser.on('--tags=TAGS', 'Specify which commits with tags to include') do |arg|
		@options[:tags] = arg.split('; ')
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
	commit_info = {}

	commit_msg = log.message.split(/-+ *PSP *-+/)
	commit_info['Details'] = commit_msg[0].split(/\n/).join(' ').split(/\t/).join(' ')

	if commit_msg[1]

		fields = commit_msg[1].split("\n")

		fields[1..].each do |field|
			temp = field.split(':')

			key = temp[0]
			value = temp[1..].join(':')

			commit_info[key] = value
		end
	end

	commit_info
end

if @options[:tags]
	psp.filter_commits do |commit|
		includes = false

		@options[:tags].any? do |t|
			if commit['Tag']
				includes = commit['Tag'].include? t
			end
		end

		# Todo exclude / include commiters
		# includes = commit[:itself].commiters.any? @options[:commiters]

		# Todo exclude / include commits

		includes
	end
end

psp.on('Changes') do |commit_info|
	commit_info['Changes'] = "-#{commit_info['Changes'].deletions.to_int} +#{commit_info['Changes'].lines.to_int} ~#{commit_info['Changes'].insertions.to_int}"
	commit_info
end

psp.on('Till') do |commit|
	begin
		date_till = Time.strptime(commit['Till'], ' %H:%M')

		date_till = Time.new(commit['Date'].year, commit['Date'].mon, commit['Date'].day, date_till.hour, date_till.min)

		commit['Date'] = date_till
	rescue StandardError
		puts("Failed to parse field 'Till' in commit #{commit_info['itself']}: #{commit_info['Till']}")
	end

	commit
end

psp.on('From') do |commit_info|
	begin
		date_from = Time.strptime(commit_info['From'], ' %H:%M')

		date_from = Time.new(commit_info['Date'].year, commit_info['Date'].mon, commit_info['Date'].day, date_from.hour, date_from.min)

		commit_info['From'] = date_from

		commit_info['Overall'] = (commit_info['Date'].to_i - commit_info['From'].to_i) / 60
	rescue StandardError
		puts("Failed to parse field 'From' in commit #{commit_info['itself']}: #{commit_info['From']}")
	end

	commit_info
end

psp.on('From', 'Interruptions') do |commit|
	begin
		time = commit['Date'].to_i
		time -= commit['From'].to_i

		# TODO: Remove this, it is kept to support some old commit messages in my project
		# interruptions = row['Interruptions'].split(';')
		# unless interruptions[1]
		# 	interruptions = row['Interruptions'].split(',')
		# end

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
