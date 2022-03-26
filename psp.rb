require 'optparse'
require 'set'
require 'git'
require 'csv2md'
require 'csv_shaper'
require 'time'

class PSP
  attr_accessor :options
  attr_reader :repo, :data, :header

  def initialize
    @options = {
      repopath: nil,
      since_commit: 0,
      till_commit: 100,
      markdown_fileout: nil,
      csv_fileout: nil,
      markdown_stdout: nil,
      csv_stdout: nil
      # TODO: Implement these options
      # csv_filein: nil,
      # :include_commiters => [],
      # :exclude_commiters => [],
      # :include_commits => [],
      # :exclude_commits => [],
      # :since_date => nil,
      # :till_date => nil,
    }

    parse_opts()

    if !@options[:csv_fileout] && !@options[:markdown_fileout] && !@options[:markdown_stdout] && !@options[:csv_stdout]
      puts 'No output options specified'
      exit
    end

    open_local_repo()
    parse_commits()

    @csv_string = to_csv()
    @markdown_string = Csv2md.new(@csv_string).gfm

    if @options[:csv_fileout]
      file = File.new(options[:csv_fileout], 'w')
      file.syswrite(@csv_string)
    end

    if @options[:markdown_fileout]
      file = File.new(options[:markdown_fileout], 'w')
      file.syswrite(@markdown_string)
    end

    if @options[:markdown_stdout]
      puts "#{@markdown_string}"
    end

    if @options[:csv_stdout]
      puts "#{@csv_string}"
    end
  end

  def open_local_repo
    @repo = Git.open(@options[:repopath])
  rescue StandardError
    puts 'Please, provide correct path to your repo'
    exit
  end

  def to_csv
    # # This is, as of yet, not supported,
    # # because `csv2md` cannot deal with
    # # other separators
    #
    # CsvShaper.configure do |config|
    #   config.col_sep = "\t"
    # end

    # Builds a cvs out of data
    csv = CsvShaper::Shaper.new

    # Builds a header
    csv.headers @header do |csv, _head|
      header.each do |head|
        csv.columns head
      end
    end

    # Builds the rest of data
    @data.each do |data_row|
      csv.row do |csv|
        data_row.each do |data_cell|
          csv.cell data_cell[0], data_cell[1]
        end
      end
    end

    csv.to_csv
  end

  private def parse_commits
    logs = @repo.log

    # Presets
    @header = Set[
      'Date',
      'From',
      'Till',
      'Interruptions',
      'Overall',
      'Action',
      'Details',
      'Changes',
    ]

    @data = []

    # Finds all headers and data
    logs[@options[:from]..@options[:till]].each do |log|
      next unless log.commit?

      row = {}

      row[:Date] = log.committer_date.to_s[5..9]
      row[:Till] = log.committer_date.to_s[11..15]
      row[:Changes] = "-#{log.diff_parent.deletions.to_int} +#{log.diff_parent.lines.to_int} ~#{log.diff_parent.insertions.to_int}"

      # PSP parsing
      commit_msg = log.message.split('--- PSP ---')
      unless commit_msg[1]
        commit_msg = log.message.split('---PSP---')
      end
        
      row['Details'] = commit_msg[0].split("\n").join(' ')
      
      # puts "COMMIT_MSG: " + commit_msg.to_s
      
      # Parses the rest of the fields
      if commit_msg[1]
        fields = commit_msg[1].split("\n")

        fields[1..].each do |field|
          key = field.split(':')[0]
          value = field.split(':')[1..].join(':')

          @header.add key

          row[key] = value
        end
      end
      
      # puts "#{row}"
      # puts "#{row['From']}"
      
      # puts "ROW: " + row.to_s + "\n\n"
      # Calculates time spend on a commit
      if row['From']
        
        begin
          date_from = DateTime.strptime(row['From'], " %H:%M")
        rescue
          date_from = nil
          puts "Failed to parse an `From` field from commit '#{log.sha}' From: `#{row['From']}`"
        end
        
        # TODO: Remove this, it is kept to support some old commit messages in mine projects
        if row['Interferences']
          row['Interruptions'] = row['Interferences']
        end
        
        commit_time = log.committer_date
        date_from = Time.new(commit_time.year, commit_time.mon, commit_time.day, date_from.hour, date_from.min,0)
        
        time = commit_time.to_i
        time -= date_from.to_i
        
        # Parses interruptions
        if row['Interruptions'] && date_from
          date_int = []
          
          # TODO: Remove this, it is kept to support some old commit messages in mine project
          interruptions = row['Interruptions'].split(';')
          unless interruptions[1]
            interruptions = row['Interruptions'].split(',')
          end
          
          interruptions.each do |int|
            int_ = int.split('(')
            begin
              # Parses "%M"
              date_int.push(Integer(int_[0]) * 60)
            rescue
              begin
                # Parses "%H:%M"
                date_int.push(Integer(int_.split(':')[0] * 60 * 60, 60 * Integer(int_.split(':')[1])))
              rescue
                puts "Failed to parse an interruption from commit '#{log.sha}' `#{int}`"
                next
              end
            end
          end
          
          date_int.each do |int|
            time -= int.to_i
          end
        end
          
        # Convertion into minutes
        row['Overall'] = time / 60
      end
      @data.push(row)
    end
    @header -= [nil]
  end

  private def parse_opts
    OptionParser.new do |parser|
      parser.banner = 'Usage: psp.rb [options]'

      parser.on('-rPATH', '--repo=PATH', 'Open local repo in that PATH') do |arg|
        @options[:repopath] = arg
      end

      parser.on('--since-commit=SINCE', Integer, 'Specify from which commit to generate, default is 0 (i.e. newest)') do |arg|
        @options[:since_commit] = arg
      end

      parser.on('--till-commit=TILL', 'Specify till which commit to generate, default is 100 (i.e. till newest 100th commit)') do |arg|
        @options[:till_commit] = arg
      end

      parser.on('-mFILEPATH', '--markdown=FILEPATH', 'Specify where to export the markdown file') do |arg|
        @options[:markdown_fileout] = arg
      end

      parser.on('-cFILEPATH', '--csv=FILEPATH', 'Specify where to export the csv file') do |arg|
        @options[:csv_fileout] = arg
      end

      parser.on('--display-markdown', 'Displays markdown output to stdout') do
        @options[:markdown_stdout] = true
      end

      parser.on('--display-csv', 'Displays cvs output to stdout') do
        @options[:csv_stdout] = true
      end

      # parser.on("--csv-in=FILEPATH", "parses") do |arg|
      #   @options[:csv_fileout] = arg
      # end
    end.parse!
  end
end

PSP.new
