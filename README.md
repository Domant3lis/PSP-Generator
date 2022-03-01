# PSP Generator

This is a tool to generate PSP (Personal software process) markdown and csv documents from git commits.

## Dependencies
`ruby` `git` [`git gem`](https://rubygems.org/gems/git) and [`csv2md`](https://rubygems.org/gems/csv2md)

## Usage
This tool assumes that commits are made often and each small improvement is in a separate commit

Inside commit messages at the end include this:
```
--- PSP ---
From: HH:MM
Interruptions: 3 (Coffee break), X (Reason)
Action: Adding tests
Custom 0: Some text
Custom 1: Some text
```

Custom fields or even other fields are not required in every commit, in that case that cell will be left empty.

### Special fields
These fields are not required, but they are treated in a special way, they are used to calculate overall time taken to complete a task.
* `From: ` - Follows when the work on a commit started
* `Interruptions` - Subtracts time from interruptions then working on a commit.

`Details: ` - this is the field where the rest of commit message is saved 

## To improve / fix

I may or may not implement these improvements, listed with no priority in mind:

* Correct time calculation across days (for example: `From: 23:30 Till: 00:30`) 
* Merge columns (i.e. custom fields) (useful for typos in commits)
* Correct time calculation with different time zones
* Collect data from a specific person(s) which made the commits

## Related documentation
<https://ruby-doc.org/stdlib-2.6.1/libdoc/csv/rdoc/CSV.html>

<https://rubygems.org/gems/csv2md>
