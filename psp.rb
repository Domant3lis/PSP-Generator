require 'optparse'
require 'set'
require 'git'
require 'csv_shaper'
require 'csv2md'

options = { 
  :from => 0, 
  :till => 100,
  :markdown => 'psp.md',
  :csv => nil,
  :markdown_out => nil,
  :csv_out => nil,
}

OptionParser.new do |parser|
  parser.banner = "Usage: psp.rb [options]"

  parser.on("-oPATH", "--open=PATH", "Open local repo in that PATH") do |arg|
    options[:path] = arg
  end

  parser.on("-fFROM", "--from=FROM", "Specify from which commit to generate, default is 0 (i.e. newest)") do |arg|
    options[:from] = arg
  end

  parser.on("-tTILL", "--till=TILL", "Specify till which commit to generate, default is 100 (i.e. till newest 100th commit)") do |arg|
    options[:till] = arg
  end

  parser.on("-mFILEPATH", "--markdown=FILEPATH", "Specify where to export the markdown file, default './psp.md'") do |arg|
    options[:markdown] = arg
  end

  parser.on("-cFILEPATH", "--csv=FILEPATH", "Specify where to export the csv file, by default it isn't exported") do |arg|
    options[:csv] = arg
  end

  parser.on("-dm", "--display-markdown", "Displays markdown output to stdout") do
    puts "AAA"
    options[:markdown_out] = true
  end

  parser.on("-dc", "--display-csv", "Displays cvs output to stdout") do
    puts "AAA"
    options[:csv_out] = true
  end

end.parse!

# p options

begin
  repo = Git.open(options[:path])
rescue
  puts "Please, provide correct path to your repo"
  exit
end

logs = repo.log

# Presets
header = Set["Date", "From", "Till", "Interruptions", "Overall", "Action", "Details", "Changes"]

data = []

# Finds all headers and data
logs[options[:from]..options[:till]].each do |log|

  if log.commit?
    row = Hash.new()

    row["Date".to_sym] = log.committer_date.to_s[5..9]
    row["Till".to_sym] = log.committer_date.to_s[11..15]
    row["Overall".to_sym] = "TODO"
    row["Changes".to_sym] = "-#{ log.diff_parent.deletions.to_int.to_s } +#{ log.diff_parent.lines.to_int.to_s } ~#{ log.diff_parent.insertions.to_int.to_s }"

    # PSP parsing
    commit_msg = log.message.split("--- PSP ---")
    row["Details"] = commit_msg[0].split("\n").join(" ")

    if commit_msg[1]
      fields = commit_msg[1].split("\n")

      fields[1..].each do |field|
        key = field.split(":")[0]
        value = field.split(":")[1..].join(':')

        header.add key
        
        row[key] = value

        # TODO: time calculations
        if row["From"]
          if row["Interruptions"]
            # TODO: Calculations
          end
        end

      end
    end

    data.push(row)
  end
end

header = header - [nil]

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
csv.headers header do |csv, head|
  header.each do |head|
    csv.columns head
  end
end

# Builds the rest of data
data.each do |data_row|
  csv.row do |csv|
    data_row.each do |data_cell|
      csv.cell data_cell[0], data_cell[1]
    end
  end
end

csv_string = csv.to_csv
markdown_string = Csv2md.new(csv_string).gfm

if options[:csv_out]
  puts "CSV:\n" + csv_string + "\n"
end

if options[:markdown_out]
  puts "Markdown:\n" + markdown_string + "\n"
end

if options[:csv] != nil
  file = File.new(options[:csv], "w")
  file.syswrite(csv_string)
  puts ""
end

file = File.new(options[:markdown], "w")
file.syswrite(markdown_string)
