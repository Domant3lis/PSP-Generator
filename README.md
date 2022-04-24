# PSP Generator

This is a tool to generate PSP (Personal software process) CSV and markdown [WIP] documents from git commits.

## Dependencies
`ruby`, `git`, `libgit`
Ruby gems: [`git`](https://rubygems.org/gems/git), [`csv2md`](https://rubygems.org/gems/csv2md), [`csv_shaper`](https://rubygems.org/gems/csv_shaper)

## Usage
This tool assumes that commits are made often and each small improvement is in a separate commit

Inside commit messages at the end include this:
```
--- PSP ---
From: TIME
Till: TIME
Interruptions: 3 (Coffee break); MM (Reason)
Tag: Task1
Action: Adding tests
Custom 0: Some text
Custom 1: Some text
```

TIME field can be formatted as: `HH:MM` or `YYYY-MM-DD HH:MM` or `YYYY-MM-DD HH:MM ±TIMEZONE` or `YYYY-MM-DD HH:MM ±TIMEZONE_HOUR:TIMEZONE_MINUTE` or `YYYY-MM-DD HH:MM ±TIMEZONE_HOUR:TIMEZONE_MINUTE:TIMEZONE:SECOND`

This tool also supports [this syntax](https://bx2.tech/vu-lff/).

### Running
Then run form the command line `./app.rb -r REPOPATH -c OUTPUT_PATH`, for additional options run `./app.rb --help`. Don't forget to chmod `app.rb`

Custom fields or even preset fields are not required in every commit, in that case that cell will be left empty in the final document.

I haven't tested this on Windows, but it should work with little to no modifications (provided all dependencies are there)

### Special fields
These fields are not required, but they are treated in a special way, they are used to calculate overall time taken to complete a task.
* `From: ` - Follows when the work on a commit started
* `Till: ` - Follows when the work on a commit ended, usually is not needed as commit timestamp is used, this option overrides the commit timestamp
* `Interruptions: ` - Subtracts time from interruptions then working on a commit.
* `Tag: ` - This field won't appear in the final table and is planned to be used exclusively for filtering commits
* `Details: ` - this is the field where the rest of commit message is saved 

## To improve / fix

I may or may not implement these improvements, listed with no priority in mind:

* Implement generation of time spent summary by action and files
* Filter data based on which person(s) made the commits
* Do time calculation from intermediary CSV files
* Integrate issue tracking
* Add tests (Currently I use [this repo](https://github.com/Domant3lis/ADS/) and visually check with this command `clear && ./app.rb -r '~/Projects/ADS' --tags 'Task2' -c 'psp.csv' --display-csv --exclude-commits 'fd81e30a2fb136; a45d6fb8cf9f0' --include-commits 'e437c1de1ec6a0; d5f9195df212d9'`)

## Architecture and extensibility
This tool is build to be as extensible as possible, in fact main functionality of this utility is implemented **outside** the main class.

Here's a short breakdown of how this works:

First, `read_commits` iterates over all commits and puts some data into a hash: diff from parent is mapped to `'Changes'`, commit date and time to `'Date'` and the commit itself (an instance of `Git::Object::Commit`, relevant documentation [here](https://rubydoc.info/gems/git/Git/Object/Commit)) to `:itself`, the rest is done in a block passed form the caller, which gets the log itself from the block argument and is expected to to return a modified hash with all the parsed fields.

Later, `filter_commits` is used to filter out commits, the argument of the block is the hash with all the commit information and it is expected to return a boolean value.

The `on`, 'on_cell' and 'on_all_cells' methods checks if a hash has specified fields and if it does yields the block. While it is possible to do all same actions in the `read_commits` block, `on` family of methods makes it easier by checking if the field exists and makes it easier to separate functionality and structure the code.

At last, `to_csv` returns a complete csv string. `exclude` argument takes an array of keys and removes all values from the commit hash matching the keys, `preset` takes a set of keys and simply ensures the order of columns by key, `col_sep` is used to specify which character is used as a separator.

## Related documentation
<https://ruby-doc.org/stdlib-2.6.1/libdoc/csv/rdoc/CSV.html>

<https://rubygems.org/gems/csv2md>

## Disclaimer
This is a personal project thus no warranty or quality assurance is provided, but feel free to send as many PRs as you wish.
