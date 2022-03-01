require 'optparse'
require 'csv'
require 'set'
require 'git'
require 'csv2md'

options = { :from => 0, :till => 100, :markdown => 'psp.md', :csv => 'psp.csv'}
OptionParser.new do |parser|
  parser.banner = "Usage: example.rb [options]"

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

  parser.on("-cFILEPATH", "--csv=FILEPATH", "Specify where to export the csv file, default './psp.csv'") do |arg|
    options[:csv] = arg
  end

  # TODO
  # parser.on("-no", "--no-output", "Doesn't display the markdown output before generating it") do |arg|
  #   options[:no_output] = arg
  # end
end.parse!

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
  puts "LOG_MSG: " + log.message

  if log.commit?
    puts "LOG_MSG?: " + log.message
    row = Hash.new()

    # For now, do not change the order, or else it will mess up the output
    row["Date"] = log.committer_date.to_s[5..9]
    row["From"] = ""
    row["Till"] = log.committer_date.to_s[11..15]
    row["Interruptions"] = ""
    row["Overall"] = "TODO"
    row["Action"] = ""
    row["Details"] = ""
    row["Changes"] = "-#{ log.diff_parent.deletions.to_int.to_s } +#{ log.diff_parent.lines.to_int.to_s } ~#{ log.diff_parent.insertions.to_int.to_s }"

    # PSP parsing
    psp = log.message.split("--- PSP ---")[1]
    if psp
      row["Details"] = log.message.split("--- PSP ---")[0].split("\n").join(" ")
      fields = psp.split("\n")

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

    else
      row["Details"] = log.message.split("--- PSP ---")[0].sub("\n", " ")
    end

    data.push(row)
  end
end

header = header - [nil] 
# pp data

# Constructs CSV file from collected data
csv_string = CSV.generate do |csv|
  csv << header.to_a
  data.each do |row|
    csv << row.values
  end
end

markdown = Csv2md.new(csv_string)
p markdown.gfm

file = File.new(options[:markdown], "w")
file.syswrite(markdown.gfm)

file = File.new(options[:csv], "w")
file.syswrite(csv_string)
