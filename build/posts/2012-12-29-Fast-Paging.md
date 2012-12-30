* title: Fast Paging
* subtitle: Floats are the Devil

Everybody in the development world (that hasn't been bitten yet) has some idea
that floats are vaguely dangerous - 'floating point error' is a boogeyman that
we all believe in, but most don't really understand. Well this post isn't really
about that. There's another danger to floats that has nothing to do with
representing currency and floating point error accumulation - MySQL does not
order by the *decimal* representation of floats, which breaks my (described below)
fast database paging algorithm in subtle ways.

Before we talk about that, I'll need to explain the algorithm in question - its
purpose, its need, and its approach. Let's approach the standard database paging
approach first. That uses `LIMIT` and `OFFSET` (which are just two arguments to
`LIMIT` often) to step by some batch size.

```ruby
page = 0
while batch.nil? or batch.length == BATCH_SIZE
	batch = relation.limit(BATCH_SIZE).offset(page * BATCH_SIZE)
	yield batch
end
```

This was the approach taken by the famously popular will_paginate gem, and
probably the appropriate approach for the needs of that purpose - aren't iterating
through records in batches, you're going straight to some page, which can't
often be done any faster than with limit-offset. The problem that arises with
that approach can be shown in one query:

```sql
SELECT * FROM stars
ORDER BY name desc LIMIT 1000 OFFSET 10000000;
```

This query doesn't just jump to the right place in the table and start iterating -
MySQL doesn't know where that place *is*. In order to find it, it has to generate
the result set in memory from disk and iterate through it 10,000,000 times
to find the right position. Now, it's a bit faster than that, since MySQL is also
batching, but it still can take a while - that query above could take minutes to
run.

When you're clicking through pages on a website, this is unlikely to happen, and
punishing your *very* determined paging-system user with a slow page load is
generally acceptable.

ActiveRecord has a `find_each` and `find_in_batches`, which do something smarter:

```ruby
max_id = 0
batch = nil
while batch.nil? or batch.length == BATCH_SIZE
	batch = relation.where('id > max_id').limit(BATCH_SIZE)
	max_id = batch.last.id
	yield batch
end
```

Which pages through the whole set, and never uses an OFFSET to make MySQL sad..
but can only do it in one order (and I'm sure you've noticed that find_each ignores
your `order` calls before) - `id ASC`, primary key order. You can of course, write
the exact same algorithm for any unique key yourself - it's not a complicated
one. But things get murkier when you order by non-unique columns, or by more
than one.

Here's an algorithm that will page through the stars ordered by `name` as in
our second example:

```ruby
max_name = nil
max_id = nil
batch = nil
while batch.nil? or batch.length == BATCH_SIZE
 	paged_rel = rel.
 		where("(name > ? OR (name = ? AND id > ?))", max_name, max_name, max_id).
 		limit(BATCH_SIZE)
 	batch = paged_rel.all
 	yield batch
 	max_name = batch.last.name
 	max_id = batch.last.id
end
```

This works *beautifully*, and there are a few notes to make about it.

* It's ordered by "name asc, id asc", not just by name. That's necessary -
	we require a fully specified ordering to perform paging, because there are
	12,000 stars named 'Bob'. If we use our previous algorithm just ordering on
	name, we will end up skipping most of them because, after the first batch
	that ends with a Bob, we'll grab all the stars *after* 'Bob'.
* Keys in MySQL have an implicit copy of the primary on the end, because an
	index is a full ordering on the table - looking up by `name, id` is indexed.
	I bring this up because if you add another column to the mix, you can run into
	problems - ordering by `name asc, location asc, id asc` requires that you have
	the `[name, location]` index defined for speed, but `name asc, location desc, id asc`
	doesn't do what you'd hope in MySQL. (In postgres, you can specify the direction
  of each column in an index, but in MySQL you're out of luck).
* Despite that, if you have a *somewhat* unique value in the first column, the
	algorithm will work fine - scanning through 12,000 Bobs only takes MySQL 125ms,
	and doesn't put a dangerous load on it.

That's fast, but it feels a bit clumsy, doesn't it? Hard to reuse, and code gets
more complicated as you add columns to the orderings. It's not terribly difficult
to write a general-purpose solution to this problem, which takes a relation, extracts
the order clauses from it, tracks the current value of each, and yields the batches..
though it is much more difficult if you want a *fully* general-purpose solution,
since handling joins (that aren't 1-to-1) is tricky, what with 'id' no longer
being a unique key in the result set. My implementation of two weeks ago took a
few hours to write, and had a bug or so in it, but it's not a marvel of eloquence
(and it belongs to my employer besides), so I won't share it here in this tiny
margin.

(If anyone is actually interested in such a thing, drop an issue on the tracker
for this blog, which is [here](https://github.com/nevinera/nevinera.github.com/issues).
I do still intend to refactor my solution, and there's no reason I couldn't put
in the extra couple of hours to make it a usable gem.)

"Wait!" You shout, "What about floats!? You made this big deal up above.."
Oh, right. The slight wrench in the ointment, floating point numbers.

If you're like me, you've probably been using `:float` columns *everywhere* -
they generally behave pretty well, and you don't always know what kind of data
you might have to shove into your poor tables.. *Don't*.

What you should usually be using, unless you have a column that really needs
a dynamic scaling range (that's honestly pretty rare), is `DECIMAL` columns.
A decimal data column specifies how many digits it gets, and how many digits
past the decimal point. The representation in the db matches the data that it
produces when you query it exactly. This matters in situations where you can
accumulate floating point error of course:

```sql
SELECT SUM(distance) FROM stars
```

will almost certainly produce a different answer than would

```ruby
sum = 0.0
Star.find_each do |s|
	sum += s.distance
end
```

But that's not the part that had me pulling hair out for an hour last week.
The real problem with floats is that:

```ruby
d = Star.find(15).distance
Star.find_by_distance(d)
```

often returns *no result*.

That's because the decimal representation we are feeding MySQL over the wire
can convert to multiple binary representations of roughly the same value - MySQL
converts it to one of those representations, and that may not be the value that
we got it from! `DECIMAL`s don't have this quality - a single decimal value can
be converted to and from its decimal string representation without concern.

This enters play on my FastPager in the following case:

```ruby
pager = FastPager.new({
	:klass => Star,
	:batch => 1000,
	:order => {:distance => :asc, :id => :asc }
	})
pager.each_page do |page|
	# do some stuff with the data
end
```

We happen to have 3000 stars of exactly the same *decimal* distance from us, but
the first half of them are actually closer than the second half, they just happen
to map to the same decimal string. Let's call that lower value `x.a` and the
higher one `x.b`. When we attempt to iterate through them, we read the first
thousand fine, then the second thousand fine, but then the query for the third
thousand gets:

```sql
SELECT * FROM stars WHERE distance > X OR (distance = X AND id > Y)
```

It translates X into X.a, and rereads the first thousand, picking up only records
that happen to have an `id` higher than Y. That's bad enough, since you get repeat
records that are out of order in your results.. but if you happen to have no ids
greater than Y in that batch (which is not terribly unlikely on the whole), you
just got an infinite loop of querying! They are indexed, and not complicated, so
you won't bring your app to its knees or anything, but your job will never finish,
and will continue querying and performing its task until some observant New Relic
watcher notices that there's a job that's been running for 5 days.

The problem was cured in every case by converting my float columns to decimals
over the appropriate range, which took a good 5 hours of migration (There're a
lot of stars in the sky, after all).


