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
From: HH:MM (eventually YYYY-MM-DD HH:MM GMT+X [WIP])
Interruptions: 3 (Coffee break); MM (Reason)
Tag: Task1
Action: Adding tests
Custom 0: Some text
Custom 1: Some text
```

Custom fields or even preset fields are not required in every commit, in that case that cell will be left empty in the final document.

### Special fields
These fields are not required, but they are treated in a special way, they are used to calculate overall time taken to complete a task.
* `From: ` - Follows when the work on a commit started
* `Interruptions` - Subtracts time from interruptions then working on a commit.
* `Tag: ` - This field won't appear in the final table and is planned to be used exclusively for filtering commits
* `Details: ` - this is the field where the rest of commit message is saved 

## To improve / fix

I may or may not implement these improvements, listed with no priority in mind:

* Implement `From: @prev_commit`
* Implement generation of time spent summary by action and files
* Overhaul how time is calculated, currently it is very janky:
	- Correct time calculation across days (for example: `From: 23:30 Till: 00:30`) 
	- Correct time calculation with different time zones
* Filter data based on which person(s) made the commits
* Do time calculation from intermediary CSV files
* Integrate issue tracking
* Implement `filter_parsed` method

## Architecture and extensibility
This tool is build to be as extensible as possible, in fact main functionality of this utility is implemented **outside** the main class.

Here's a short breakdown of how this works:

First, `read_commits` iterates over all commits and puts some data into a hash: diff from parent is mapped to `'Changes'`, commit date and time to `'Date'` and the commit itself (an instance of `Git::Object::Commit`, relevant documentation [here](https://rubydoc.info/gems/git/Git/Object/Commit)) to `:itself`, the rest is done in a block passed form the caller, which gets the log itself from the block argument and is expected to to return a modified hash with all the parsed fields, in fact, it is possible to implement a completely different syntax just by changing this block (as long as the keys remain the same, otherwise the new keys need to be mapped to the old ones), for example [this one](https://bx2.tech/vu-lff/).

Later, `filter_commits` is used to filter out commits, the argument of the block is the hash with all the commit information and it is expected to return a boolean value.

The `on` method checks if a hash has specified fields and if it does yields the block. While it is possible to do all same actions in the `read_commits` block, `on` it makes it easier by checking if the field exists and makes it easier to separate functionality and structure the code.

At last, `to_csv` returns a complete csv string. `exclude` argument takes an array of keys and removes all values from the commit hash matching the keys, `preset` takes a set pf keys and simply ensures the order of columns by key, `col_sep` is used to specify which character is used as a separator.

## Related documentation
<https://ruby-doc.org/stdlib-2.6.1/libdoc/csv/rdoc/CSV.html>

<https://rubygems.org/gems/csv2md>

## Disclaimer
This is a personal project thus no warranty or quality assurance is provided, but feel free to send as many PRs as you wish.
