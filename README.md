# PSP Generator

This is a tool to generate PSP (Personal software process) markdown and csv documents from git commits.

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

NOTE: `Tag: ` field is WIP and currently does not work

Custom fields or even other fields are not required in every commit, in that case that cell will be left empty.

### Special fields
These fields are not required, but they are treated in a special way, they are used to calculate overall time taken to complete a task.
* `From: ` - Follows when the work on a commit started
* `Interruptions` - Subtracts time from interruptions then working on a commit.
* `Tag: ` - [WIP] This field won't appear in the final table and is planned to be used exclusively for filtering commits
* `Details: ` - this is the field where the rest of commit message is saved 

## To improve / fix

I may or may not implement these improvements, listed with no priority in mind:

* Implement `From: @prev_commit`
* Implement tags
* Implement generation of time spent summary by action and files
* Improve how fields are parsed; it's janky
	IDEA: each fields (or a group of fields) parsing should be moved into separate blocks such that they could be extented by passing blocks into extend() method
* Overhaul how time is calculated, currently it is also very janky:
	- Correct time calculation across days (for example: `From: 23:30 Till: 00:30`) 
	- Correct time calculation with different time zones
* Collect data from a specific person(s) which made the commits
* Produce an intermediary CSV file, switch could be edited manually and then do time calculation
* Ctrl+F for TODOs arround the codebase for more

## Related documentation
<https://ruby-doc.org/stdlib-2.6.1/libdoc/csv/rdoc/CSV.html>

<https://rubygems.org/gems/csv2md>
