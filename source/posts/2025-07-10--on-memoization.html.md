---
title: On Memoization
date: 2025-07-10
summary: >
    Everybody is familiar with memoization. It's one of the first bits of ruby you learn about,
    but to me it means something special, and not something particularly performance-related.
published: false
---

Memoization is "an optimization technique" - it refers to the standard strategy of remembering
or caching the output of an expensive computation, so that it can be returned without re-running
the computation in the future. There are some standard idioms for it:

```ruby
# The simplest idiom
def foo
  @foo ||= calculate_foo
end

# The safer idiom (because your calculation might return nil or false)
def foo
  return @foo if defined?(@foo)
  @foo = calculate_foo
end

# The more performant idiom (see Aaron Patterson's talks on Object Shape)
class MemoizingThing
  def initialize
    @memoizations = {}
  end

  def foo
    return @memoizations[:foo] if @memoizations.key?(:foo)
    @memoizations[:foo] ||= calculate_foo
  end

  def bar
    return @memoizations[:bar] if @memoizations.key?(:bar)
    @memoizations[:bar] ||= calculate_bar
  end
end
```

And of course my favorite, which basically does the latter, but more thoroughly:

```ruby
# use the `memery` gem
class MemoizingThing
  include Memery
  memoize def foo = calculate_foo
end
```

Those.. aren't what I want to talk about. Though I'll be using the last of them in all my examples
from here.

### When can you memoize something?

In general, you can only memoize something when you _don't expect its value to change_ (over the
lifetime of instantiated object. Be careful memoizing onto Classes and other Singletons, they live
for a long time!) And that's how most of us use it - "I'm pretty sure this doesn't ever change, so
I'll hold onto it".

But the thing is, knowing that about a method is _powerful_ - it's actually a statement of
"invariance", and it makes reasoning about behavior simpler. If the value doesn't change, then
when we define the memoized method we're _declaring the meaning of that method_. Declarative
programming is far easier to follow than imperative, because that's how we _think_ about things:
we can understand what each defined "thing" represents, without having to model any mental
_state_. It's rarely relevant in _my_ code, but it also tells the reader that the method is
**state-invariant**; if there _is_ any mutable state in the object, _this method doesn't care_.

And what I have found is that the _more_ methods I memoize on an object, the better. Ideally (and
usually) I can memoize _every_ method - this is what I call a "lazy/immutable object."

### A Lazy/Immutable Object... That's a rock. You've described a rock.

Well, mostly I've described anything that doesn't move, so yeah a rock is a good example. Not
very relevant to software though.. Here's a bit of code that is _not_ lazy and immutable:

```ruby
class StringParser
  def parse_string(s)
    result = []
    s.strip.split(/\s+/).each do |token|
      parsed_token = parse_token(token)
      result << parsed_token if parsed_token
    end
    result
  end

  private

  def parse_token(token) = token.gsub(/[^a-z]+/i, "_").upcase.to_sym
end
```

It's pretty straightforward really - I'm not trying to create a complex problem to really pick at.
And it could be a _lot_ worse - there is no actual state being modified.. Okay here's a worse
version:

```ruby
class StringParser
  def initialize(str)
    @str = str
    @parsed = false
  end

  def parse_string!
    @result = []
    @str.strip.split(/\s+/).each do |token|
      parsed_token = parse_token(token)
      @result << parsed_token if parsed_token
    end
    @parsed = true
  end

  def result
    fail(NotReadyError, "need to parse_string! first") unless @parsed
    @result
  end
end
```

And if you think that looks _artifically bad_, well.. it is. But I've seen basically that same
code at least five times in different repositories I needed to work on; this is the _normal_ kind
of bad. Now for the alternative (well, the one I'm backing here), lazy/immutable style, also called
"why did you memoize so many methods?". (Named for the PR comment I get six times my first week in
any new role). The answer is that, to me `memoize` isn't a performance tool, it's an _annotation_ -
when I mark a method as memoized, I _might_ be improving its performance, but I'm mostly just
indicating that it's invariant, which is important to know (not having to think about whether a
method _should_ be memoized, since it invariably already was.. that's just a bit of a bonus).

The _goal_ when you're writing something in this style is to _pick good method names_. And yes, I'm
aware that that's the hardest part of software engineering (aside from style-guide consensus; I'll
post on that topic another day). In every case possible, pick _nouns_ - complex noun phrases are
fine, so long as the person reading the name of the method doesn't need to read the method again
to recall what it does. (Ideally, they won't have to read it in the first place, and will just
_assume_ that it does what the name says it does, but that's a high bar, and you'll only be able
to construct such a name maybe two-thirds of the time in reality.) Usually, you can get away with
having _no_ methods that take any arguments - if you can't make that work, it's frequently an
indicator of a missing abstraction, which I'll show you in a moment.

What "things" are there that we could give a definition for? Well, we have a "string", the input.
We have a "result", the output. We also have the "tokens" - that's what you get when you split the
string up for processing (`@str.strip.split(/\s+/)`). And that `parse_token` method - it looks like
it's cleaning the token up and then making it into an upcased symbol? This is where the
"memoization is for performance" people start squinting at me, but remember that _that_ is not my
goal most of the time (I work mostly on Rails apps, so while there are _occasionally_ places that
_this_ sort of performance difference matters, it's so rare that I can discard it as a factor by
default. In rails, performance means "make fewer trips to the database", or occasionally "stop
writing 9-layer joins".) We're going to break that single method up into two steps, creating an
intermediate result, `cleaned_tokens`.

```ruby
class StringParser
  include Memery

  NUMERIC = /\A\d+\z/

  def initialize(str)
    @str = str
  end

  # Yes, we _could_ just stick the definition of `transformed_tokens` here. But then it doesn't
  # have a meaningful *name*, and that's the whole point.
  memoize def result = transformed_tokens

  private

  memoize def transformed_tokens = cleaned_tokens.map(&:upcase).map(&:to_sym)

  memoize def cleaned_tokens = tokens.map { |ct| ct.gsub(/[^a-z]+/i, "_") }

  memoize def tokens = str.strip.split(/\s+/)
end
```

I wrote that in the order that it appears, and that's a frequent pattern - you write the result
in terms of other methods that don't exist yet, and then you write each of _those_ methods the same
way, until you no longer need any further methods to express the definitions.


### That seems contrived. I usually need parameters on my methods.

That's the neat thing, you probably don't! Let's make a version of the thing above that _would_
be pretty awkward to write without such a method:


```ruby
def parse_token(token)
  if token =~ /foo/i
    :foo
  elsif token =~ /bar/i
    :bar
  elsif token =~ /\A\d+\z/
    :"numeric_#{token.to_i}"
  else
    token.to_sym
  end
end
```

This is a silly example, but a typical pattern - map across the _things_, doing some complicated
operation to each of them. And I _can't_ write that as a lazy/memoized implementation (without
doing some gymnastics around zipping mapped sparse partial-results, which I will spare you). I'd
write it as two.

```ruby
class StringParser
  include Memery

  def initialize(str)
    @str = str
  end

  memoize def result = transformers.map(&:result)

  private

  memoize def tokens = str.strip.split(/\s+/)

  memoize def transformers = tokens.map { |tok| Transformer.new(tok) }

  # I refer to these as "inner" classes. If it gets complicated, it deserves its own file, but
  # fundamentally it's a "domain wrapper" for the unparsed token, which exposes the parsed token
  # as an attribute.
  class Transformer
    include Memery

    def initialize(token)
      @token = token
    end

    attr_reader :token

    memoize def foo? = /foo/i.match?(token)
    memoize def bar? = /bar/i.match?(token)
    memoize def numeric? = /\A\d+\z/.match?(token)
    memoize def number = token.to_i

    memoize def transformed
      return :foo if foo?
      return :bar if bar?
      return :"numeric_#{number}" if numeric?
      token.to_sym
    end
  end
end
```

Now, this is a toy problem, but I probably _would_ actually write the latter code here, despite
that it's almost twice as long as the first implementation would be. And the reason is that this
version _grows_ better. Rather than procedural code defining _how to parse a string_, we have
declarative code defining _what a parsed string is_. If the logic about how to parse that string
changes in any of a hundred ways, it will be _obvious_ in the declarations, and usually
straightforward (when it's not, because the structure of the thing needs to change, that's when
you should be really glad for the style).

Let's change the above by.. adding a new type of token? Well, that's pretty easy, we just add
`return :emoji if emoji?` and then defined the predicate. What if the process for scanning out
the tokens changes? That's more substantial, but it's really clear where to touch - the definition
of `tokens` is no longer accurate - it might need another (Tokenizer?) class if the process is
complex enough, but it'll be surgical, because we can see where the definition of `tokens` is,
and replace it (or conditionalize it.

```ruby
memoize def tokens = use_json? ? json_tokens : split_tokens`
memoize def use_json? = !!@options[:json] # (now optionally supplied to initializer)
memoize def json_tokens = JSON.parse(string)
memoize def split_tokens = str.strip.split(/\s+/)
```

### That's just like procedural code, with extra steps!

Well yeah, kind of. You _could_ write this as a process that just calculates each of those things
and sticks it in a variable, doing so in the correct order. That code would be similarly easy to
read actually, just hard to modify. And honestly, you should do that if it helps: write out the
procedural approach (with good variable names), then turn variable-setting into lazy methods and
control structures into classes - that will usually construct a fairly reasonable result.

A fresh baguette is just flour, yeast, water, and salt with a few extra steps!

I want to reassure you though that this is not just a theory. I've been writing the vast bulk of
my code this way for six years or so, and I've had no regrets, nor heard any (aside from confused
complaints about the number of memoizations) from the inheritors of the huge swathes of code I've
produced this way, only occasional thanks. You don't need to dive as hard into this as I have, but
please try the style out when you get a chance!
