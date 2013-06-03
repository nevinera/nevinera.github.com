* title: Text Manipulation with Unix and Ruby
* subtitle: Avoiding Regular Expressions for Fun and Profit

`cat ~/data.txt | cut -d ',' -f 3,4 | sort | uniq | wc -l`

I just counted the distinct combinations of values found in two columns
of a 6-gig csv file; it took about 30 seconds.

`cat ~/data.txt | cut -d ',' -f 3,4 | sort | uniq -c | sort -n -r > /tmp/output.txt`

That time I asked how many times each of those pairs occurred, and I asked
it to tell me the most frequent combinations first (and to stick the results
in a file for me to view, since there may be many of them).

Text processing is a complex topic, and there are many approaches to it to consider;
the first of the two we'll be talking about today is called 'UNIX'.

## Unix

Unix is a somewhat loose term in this context, and it's real definition isn't germane.
A quick read of the wikipedia article might interest you, but the important thing
for our purposes is really more of the *philosophy* of Unix, and the collection of
command-line tools that is universally distributed with it. Unix utilities have a few
driving principles in common: "Everything is a File", and "Files Have Lines".

Most unix utilities are intended to operate on the lines of a file, either individually
or in aggregate - the `grep` utility is used to filter a file down to the lines of interest,
while the `sort` utility is used to put them in some order, and `wc -l` will count them for you.

### Text Streams

There are a few overarching bits of syntax to describe first. Every unix program has three
streams of data - think of it as a box with a big pipe going in, a big pipe coming out, and
an information cable sticking out the side. These three streams of data are called `stdin`, `stdout`,
and `stderr`.

When you give information to a program, you can often tell it some file to look at,
but if you don't do that, it almost always means you want it to look at the stuff coming in on `stdin`;
the text you are feeding into it's intake pipe. Likewise, if you just run a program on the command line,
`stdout` is by default your terminal, which means it all gets printed to the screen in front of you.
With large files, that is seldom what you want, and there are various ways to do other things with it
that we'll go into in a moment.

`stderr` is different - it's not intended as a way to import or export data from
a given program; the text printed on stderr is always intended for a *human* to read.
It's the diagnostic output for a given program. `grep` can read a 9 gigabyte file, and
print out 20,000 lines that turned out to be relevant.. but if something goes *wrong*,
it will tell you that on `stderr`: "That file was not found", "I didn't understand your question", etc.

There are several ways to make these file streams point where you want them to.
The first way is called..

#### File Redirection

On the command line (in the bash shell specifically, but if you're using anything else
you probably know enough that you won't get much from this article), the characters `>` and `<`
have special meaning - they tell the preceding program to use some specific *file* as
one of its streams. `< myfile.txt` means "And read myfile.txt as your input stream";
`> myotherfile.txt` means "Write your output stream into myotherfile.txt". You can double up
the output symbol: `>> myotherfile.txt` means "*Append* your output stream onto myotherfile.txt".

We'll use the `cat` command to demonstrate - `cat` is short for 'concatenate', and it simply
accepts one or more input files or a stream and writes them to its output stream.

`cat < input.txt > output.txt`

This *essentially* just copied input.txt to output.txt. It didn't do it as fast as the `cp`
command would have either.

`cat < input.txt >> output.txt`

Now we have *appended* input.txt onto the end of output.txt. If we have already
run the command above, we should see that output.txt is twice as long as input.txt.
You can see that via `wc -l input.txt output.txt` - it will show you line counts for each
of its arguments.

This is all mildly handy, but kind of awkward - if you want to do anything for which there
is not already a unix utility, you're kind of stuck. Or would be, except for..

#### Stream Piping

There is another special character you ought to know about; it's called the 'pipe' character: `|`.
It is used to tell a program to hook its output stream directly to the input stream
of some other program. Here's an example:

`cat < input.txt | wc -l`

I told `cat` to pick up its input from `input.txt`, and then I told it to send its output to
`wc -l`, which will just count the lines it sees and print a number. That construct isn't very
useful, because you can easily just say `wc -l input.txt` (this is referred to as a "Useless
Use of `cat`"), but it demonstrates pipe operator well enough I think.

Here's a more useful one, from the top of the post:

`cat < ~/data.txt | cut -d ',' -f 3,4 | sort | uniq -c | sort -n -r > /tmp/output.txt`

This construction 'pipes' data into cat, cut, sort, uniq, and sort again, then directs the output
into a file so that we can review it at our leisure.  (`cat` is again uselessly-used,
but I prefer to use it this way for conceptual clarity).

We'll go over some details of the individual steps in this pipeline in a moment, but briefly:

* `cut` is used to extract specific columns of a csv (non-quoted, sadly).
* `sort` sorts a file in various ways - it can handle surprisingly large files, but it can take some time.
* `uniq` removes duplicates from a stream. It only removes them when they're *adjacent*, which is why we sorted first.

It turns out that, by combining fairly specific utilities in different ways, you can do *very*
complicated things - this command will produce a list of distinct combinations of values in two columns,
ordered by how often each pairing occurs in the file.

When you string a bunch of commands together like this, you are using the simplest form of multi-processing,
as well. Each of those pieces of the pipeline is its own program, and can run on a separate processor,
which means that you can use a modern computer to do things *blazing* fast, even with very large files.


### A Brief Survey of the Tools

I will be describing a few of the command line tools and arguments that I use regularly here, in brief.

For a more full description, one can consult google, but the most helpful result will usually
be the 'man page'. You can see that in your own terminal by running `man cut` or `man cat`
(the resulting view uses the 'less' pager - you can navigate with the arrow keys and pgup/pgdown,
and exit with `q`, but you might find the web version easier to read).

#### `cat`

`cat` is pretty straightforward. You use it to take inputs and tape them together:

`cat f1.txt f2.txt f3.txt > out.txt` will produce a file called 'out.txt' that is made up
of the input files stuck together end-to-end. `stdin` comes before all the arguments, so
`cat f2.txt f3.txt < f1.txt > out.txt` would produce the same result.. unless you use the
`-` argument. That would look like `cat f1.txt - f3.txt < f2.txt > out.txt` (which produces
exactly the same output). This is particularly useful when you're trying to glue a header
onto something as it flies past:

`cat hugefile | cat header.txt - > /huge.with-header.txt`

The `-n` argument tells `cat` to stick a line number in front of each line as it passes.

#### `cut`

`cut` is used to split input lines up based on a separator character. It's not aware of
quoting, so you'll end up using it sparingly on real-world files.

The most important arguments are:

* `-d ','` - the value of this argument is the 'delimiter' - the character the split the line on.
* `-f 3,4-6` -  the value after the `-f` argument is a description of which parts of the line you are interested in.

The delimiter is usually going to be either a comma or a pipe character.
If you ask for fields 3-1000000, it will usually give you all the fields except 1 and 2 -
`cut` doesn't mind that there aren't a million fields there, it just gives you what it can.

`cut -d ',' -f 1 < infile.txt > first_column.txt`

This will give you a file containing just the first column of the original file.

`cut -d ',' -f 2-1000 < infile.txt > rest.txt`

That will give you a file containing the *rest* of the columns from the original file.

#### `sort`

Sorting is expensive, and unix-sort is very good at handling files that would be very difficult to sort
normally - files that don't fit in available memory, for example, will be split up onto disk, sorted separately,
and merged back together.

You often use `sort` with no arguments, so that lines that are identical will appear adjacent,
making them suitable for `uniq`ing.

`cat input.txt | sort > output.txt`

There are a few main arguments that you'll need from time to time:

* `-f` means 'ignore case'
* `-n` means 'sort numerically'. This means that 10 will come after 9, instead of after 1.
* `-r` means 'reverse the output', so you can get a descending sort.

#### `uniq`

The sister of `sort`, uniq rarely shows up alone. You do sometimes see it in unnecessary places
for performace reasons - sorting is expensive, and uniqueing is almost free, so running a unique *before*
a sort and also *after* is totally reasonable, even though it would produce the same output if
you skipped the first call to `uniq`.

* `-c` - stands for 'count'. You'll get a count of how many identical lines were reduced down to each unique line.
* `-i` - case-insensitive. Collapse 'hello' and 'HELLO' when they are adjacent.

You will often see `uniq -c` piped to `sort -n -r` to produce a list of uniq items, with the
most frequent items at the top.

#### `wc`

It stands for 'word count', and it's a useful informational tool. Run with no arguments, it'll
print out several numbers: `line_count`, `word_count`, and `character_count`.
If any options are supplied, it will print out only the values for those options.

* `-l` just print out a line-count. This is the most frequently used option.
* `-w` word-count. Words are strings of characters separated by whitespace (including newlines).

If you give wc a list of files (or a 'glob', which is a filename with a wildcard in it),
it will print out information for each of them, which can be useful for comparison:

```bash
wc -l *.txt

     15 /tmp/f1.txt
     14 /tmp/f2.txt
   1022 /tmp/f3.txt
```

#### `tr`

`tr` stands for 'translate' - it replaces specific characters with other characters.

You can use it to remove all pipes from a file, to replace commas with pipes, to remove all spaces, etc.

With no flags, it takes two arguments - the characters to remove, and the characters to replace them with.

`tr 'aeiou' '      ' < input.txt > output.txt` will replace all vowels with spaces.

The only argument you are likely to use is `-d` - it means 'remove the characters instead of replacing them'.
You supply it like:

`tr -d 'aeiou' < input.txt > output.txt` - it will simply remove the vowels from the stream.


## Ruby

Ruby is a scripting language, much like bash (which is the language you are typing into your terminal),
but much more pleasant to read and write. A full introduction to ruby is really beyond the
scope of our conversation; I'm going to focus on the simpler parts that one can use to 
manipulate files, run unix commands, and transform text.

### Making a ruby script

A ruby script is any file containing ruby code. It generally should have a name that ends with '.rb',
and you run it as a program by calling `ruby myscript.rb`. It can be included in a pipeline like any program:

`cat myfile.txt | sort -n -r | ruby replacename.rb | sort | uniq > /tmp/out.txt`

To start with, let's discuss a ruby script that processes lines of text, much like most unix utilities do.
Here is our script:

```ruby
line_number = 0
STDIN.each_line do |line|
  line_number += 1
  
  if line_number.even?
    STDOUT.puts line.chomp
  else
    STDOUT.puts line.chomp.reverse
  end
end
```

This silly script reads lines from stdin, and reverses all of the odd lines. I'll describe some details:

* `STDIN`, `STDOUT` - these constants refer to the input and output streams we talked about above. In ruby,
  they have some useful methods on them - they are of type `IO`, which means you iterate the lines,
  you can write to them, etc.
* `line_number` is a 'variable' that is tracking which line you're on. Without knowing that, it would be tough
  to figure out which ones are odd.
* `even?` is the name of a method on numbers, which returns `true` or `false` depending on whether the number is even.
* `.each_line do |line|` is a special ruby thing - this is called a 'block', and it's a way for you to pass
  _code_ to a function. In this case, we're calling `each_line`, and then we're telling it what to *do* for each line.
* `chomp`, `reverse` - these are methods on `String` - ruby provides a *lot* of methods on the string class,
  which can come in handy. `chomp` removes newlines from the ends of lines, and `reverse` reverses the string front-to-back.
* `STDOUT.puts` - this writes a string to stdout. It also adds a newline to the end, which is why I called `chomp`
  on them first.

### Console Scripting in Ruby

Sometimes you are faced with a monotonous but daunting task - run a command for each of a hundred files, or download
and import a file a dozen times. You can generally accomplish those tasks using bash, but it's frequently much easier
to do it in Ruby.

The important constructs are the `system` call, and backticks.

#### `system`

The `system` function in ruby shells out to bash to do something. You could for example run
`system("cp /tmp/f1.txt /tmp/f2.txt")` to run the bash copy command from within ruby. When
using `system`, the bash command being run uses the ruby script's stdin and stdout as its own.
A ruby script like this one:

```ruby
system "ls /tmp"
```

will actually print the same thing as just running `ls /tmp` does.

More usefully, we could do:

```ruby
paths = [
  "/tmp/f1.txt",
  "/tmp/f2.txt",
  "/tmp/f3.txt"
]

paths.each do |path|
  destination = path + ".out"
  STDERR.puts "\n\n\nProcessing #{path} into #{destination}\n\n\n"
  system "myscript #{path} > #{destination}"
end
```

That script runs some command (`myscript`) on each of the three files listed in `paths`.
It puts the output of `myscript` in a file like "/tmp/f1.txt.out".

You see a new bit of syntax that's very important now - in a double-quoted string, `#{}` means 'interpolate'.
If you have a variable `myvar` which contains the string 'Salut', and you have the string
`"my variable is #{myvar}"`, the string evaluates to "my variable is Salut".

`myscript` could be doing almost anything here. A more specific example addressing a problem
somebody asked me about recently would look something like:

```ruby
directories = [
  "/tmp/dir1",
  "/tmp/dir2",
  "/tmp/dir3"
]

directories.each do |dir|
  file1 = "#{dir}/f1.txt"
  file2 = "#{dir}/f2.txt"
  dest1 = "#{dir}/out1.txt"
  dest2 = "#{dir}/out2.txt"

  STDERR.puts "\n\n   Processing directory #{dir}\n\n"

  system("script1 #{file1} #{file2} > #{dest1}")
  system("script2 #{file1} #{file2} > #{dest2}")
end
```

### CSV parsing in Ruby

One very important thing for our purposes that you can do in Ruby but that is very painful in Unix is
proper CSV parsing, with quoted strings. This document:

```
a,b,"c"""
d,"e,f",g
```

Should have two rows, with three fields each, but if you split on 'comma', your second row has four fields instead.

So we can use the `csv` library:

```ruby
require `csv`

line_number = 0
STDIN.each_line do |line|
  line_number += 1
  parts = CSV.parse_line(line)

  if parts.length < 10
    raise "Short row encountered on line #{line_number}"
  end
  
  parts[0] = parts[0].downcase

  STDOUT.puts CSV.generate_line(parts)
end
```

That script parses each line using csv, downcases the first field, then prints them back out (again using csv).
This is most often how you need to interact with csv files - break the line up into fields, operate
on one or more of the fields, then put them back together into a csv line and output it.

A few new details here:

* `parts.length` - parts is an `Array` - it has a length, and you can access individual members of the array with brackets.
* `CSV.parse_line` takes a string and parses it as a line of csv into an array of fields.
* `CSV.generate_line` does the opposite, taking a list of fields and building a csv line from them.
* `.downcase` is a method strings have, which turns all uppercase letters into their lower equivalent.
* `raise()` raises an exception. If run, it halts the program, prints its message (on stderr), and gives you a stack trace
  so you can tell where it came from. You often should raise an exception when you encounter a condition you did not
  expect to encounter, so you can go figure out whether your assumption is wrong, or your code.


### Google-Foo

Ruby provides a *lot* of functionality for you, especially to deal with manipulating strings, arrays, and files.
To find documentation about the specific type of object you are working with, just search for 'Ruby 1.8.7 Array'
(or whatever version of ruby you are using. You can see that using `ruby -v`).

The page for ruby strings is particularly worth reading, but the CSV library has documentation as well. Or you can
always ask ruby developer - finding the right documentation page to look at is usually the first step in solving
any problem!
