require 'set'
require 'git'

class PSP
	attr_reader :repo, :data

	def initialize(repopath)
		open_local_repo(repopath)

		@data = []
	end

	def open_local_repo(repopath)
		@repo = Git.open(repopath)
	rescue StandardError
		puts 'Failed to open repo, specified path may be incorrect'
		exit
	end

	def read_commits(&syntax)
		logs = @repo.log

		logs = logs.select { |c| c.commit? }

		logs.each do |log|
			commit_info = {}

			commit_info[:itself] = log
			commit_info['Date'] = log.committer_date
			commit_info['Changes'] = log.diff_parent

			commit_info.merge! syntax.call(log)
			@data.push(commit_info)
		end
	end

	def on(*keys, &block)
		@data.map! do |commit_info|
			if keys.all? { |k| commit_info.key?(k) }
				commit_info = commit_info.merge block.call(commit_info)
			end

			commit_info
		end
	end

	def on_cell(key, &block)
		@data.map! do |commit|
			if commit[key]
				commit[key] = block.call(commit[key])
			end

			commit
		end
	end

	def on_all_cells(&block)
		@data.map! do |commit|
			commit.each do |key, cell|
				commit[key] = block.call(cell)
			end
		end
	end

	def filter_commits(&filter)
		@data.select! { |c| filter.call(c) }
	end

	def build_header(preset, exclude: [])
		@data.each do |row|
			exclude.each { |e| row.delete(e) }
			preset += row.keys.to_set
		end
		preset - [nil, :itself]
	end

	def to_csv(exclude: [], preset: Set[], col_sep: "\t")
		exclude.push :itself
		header = build_header(preset, exclude: exclude)

		# Be wary `csv2md` cannot deal with
		# other separators than '\t'
		CsvShaper.configure do |config|
			config.col_sep = col_sep
		end

		csv_shaper = CsvShaper::Shaper.new

		# Builds a header
		csv_shaper.headers header do |csv, _head|
			header.each do |head|
				csv.columns head
			end
		end

		# Builds the rest of data
		@data.each do |data_row|
			exclude.each { |e| data_row.delete(e) }

			csv_shaper.row do |csv|
				data_row.each do |data_cell|
					csv.cell data_cell[0], data_cell[1]
				end
			end
		end

		csv_shaper.to_csv
	end
end
