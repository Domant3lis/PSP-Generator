def date_parse(commit, key, sep = ' ')
	time_str = commit[key].lstrip

	case commit[key]
	when / *@prev_commit/
		temp = commit[:itself].parent.committer_date

		# Parses full date and time with timezone
	when / *[0-9]+-[0-9]+-[0-9]+#{sep}[0-9]+:[0-9]+#{sep}[+-][0-9]:[0-9]+:[0-9]+/
		temp = Time.strptime(time_str, "%Y-%m-%d#{sep}%H:%M#{sep}%::z")

	when / *[0-9]+-[0-9]+-[0-9]+#{sep}[0-9]+:[0-9]+#{sep}[+-][0-9]+:[0-9]+/
		temp = Time.strptime(time_str, "%Y-%m-%d#{sep}%H:%M#{sep}%:z")

	when / *[0-9]+-[0-9]+-[0-9]+#{sep}[0-9]+:[0-9]+#{sep}[+-][0-9]+/
		temp = Time.strptime(time_str, "%Y-%m-%d#{sep}%H:%M#{sep}%z")

	# Parses full date and time
	when / *[0-9]+-[0-9]+-[0-9]+#{sep}[0-9]+:[0-9]+/
		temp = Time.strptime(time_str, "%Y-%m-%d#{sep}%H:%M")

		temp = Time.new(temp.year, temp.mon, temp.day, temp.hour, temp.min, commit['Date'].zone)
	# Parses only hours and minutes
	when / *[0-9]+:[0-9]+/

		temp = Time.strptime(time_str, '%H:%M')
		temp = Time.new(commit['Date'].year, commit['Date'].mon, commit['Date'].day, temp.hour, temp.min, commit['Date'].zone)

		if temp > commit['Date']
			temp -= 60 * 60 * 24 # One day
		end
	else
		temp = commit[key]
		puts("WARN: Failed to parse field 'From' in commit #{commit['itself']}: #{commit[key]}")
	end

	commit[key] = temp
	commit
end

def psp(repo)
	repo.read_commits do |log|
		commit = {}

		commit_msg = log.message.split(/-+ *PSP *-+/)
		commit['Details'] = commit_msg[0]

		if commit_msg[1]

			fields = commit_msg[1].split("\n")

			fields[1..].each do |field|
				temp = field.split(':')

				key = temp[0].capitalize
				value = temp[1..].join(':')

				commit[key] = value
			end
		end

		commit
	end
	repo
end

def lff(repo)
	reg = /LFF: */mi
	repo.read_commits do |log|
		commit = {}

		commit_msg = log.message.split(/<([^>]*)>/)

		commit_msg[1..].each do |field|
			temp = field.split('=')

			unless temp[1] then next; end

			key = temp[0].capitalize
			value = temp[1]
			commit[key] = value
		end

		temp = log.message.split("\n")

		# The else part is wanted only if checking for 'LFF: ' part
		# of the commit message is turned off
		if temp.size > 1
			commit['Action'] = temp[0].sub(/lff: /mi, '')
			commit['Details'] = temp[1..].join(' ').gsub(/<.*>/, '')
		else
			commit['Details'] = log.message
		end

		commit
	end

	map_key = proc do |from_key, to_key|
		repo.on(from_key) do |commit|
			commit[to_key] = commit[from_key]
			commit.delete(from_key)
			commit
		end
	end

	map_key.call('Start', 'From')
	map_key.call('Disturbances', 'Interruptions')

	repo
end
