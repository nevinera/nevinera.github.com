* title: Back to the C
* subtitle: A little bit faster than Ruby

There is a general truism in my industry - developer time costs more than computer time.

That's a fairly new valuation - for decades, computers were *way* more expensive than
engineers, and 'expressive' higher-level languages were pretty much relegated to academia
(with some notable exceptions). But computers continue to get faster, and programmers (despite
the explosion of tutorial books and CS programs) are not really getting any smarter.

The development of software languages and their uptake is a very interesting topic, but I'm
no computer historian; this topic is only relevant because it has led to the development of
the language I do most of my work in, Ruby. Ruby is very expressive and pleasant to work in,
but it not *fast*.

Now, that term gets thrown around a lot when comparing other languages to Ruby, but it's
only rarely really relevant - implementing complicated logic can be done 'fast' in Ruby,
as can reading and understanding other people's code. *Computation* is the part of Ruby that
is slow, and we do surprisingly little of that in most software fields!

Emcien (my employer) has a number of rails applications concerned with importing, displaying,
and presenting very complicated data to its users, and none of that requires any real computation
in Ruby - MySQL does the heavy lifting there, traversing BTrees, maintaining indices, and
moving data between disk and memory in efficient ways. The rails applications are almost entirely
*logic* - what kind of data do I need in this case? What are the portion of the results of
that query should I present to the user? How can I present these data structures visually?

But behind those rails applications, there is a program that we usually refer to as 'The Engine'
(or sometimes as 'Roy', after our lead scientist who wrote most of that code. That metaphor gets
more confusing when said scientist is actually involved in conversations though.) This engine is
a C program (though it could be mistaken for FORTRAN if one squints) responsible for taking *huge*
quantities of data, performing analysis on them, and exporting results as a file. This engine could
not *possibly* be written in Ruby - just reading *in* a 3 gigabyte file takes minutes in that world.

Instead, we have 40,000 lines of C code for taking that data, manipulating it into sparse matrices,
performing various analyes on it, tracking all kinds of relationships, and eventually dumping it
out into another file. And it all takes 30 seconds, and a few hundred megabytes of memory.

Recently, I've been writing a lot of code in C, mostly reimplementing those same algorithms anew
as modularly as possible. And I'm having to overcome old reflexes, which insist that traversing an
array of 20 million entries and doing something to each of them is *simply absurd*, that sorting
400,000 structures *cannot be done*. Because they can, in C. And it takes seconds or less.

But writing in C is *hard!* I spend more time debugging that coding; I'm having to design
data-structures to hold every little thing. I learned how to program originally in this language,
how have I forgotten so much? I'm becoming convinced that I never really learned it, that my
CS degree taught me only syntax and notation, and I'm wondering how many people come out of
those schools thinking they know how to program that couldn't do a single project-euler problem.
Our schools have unfairly conflated *knowing* with *understanding*, and it set me back years;
I've no doubt it has damaged others far more.

I apologize if you were reading this for information or edification - I'm sure I'll post more about C
another day with those things in mind. But for now, the take-away is: If you can't think of any way
to accomplish a task fast enough, there is always C!

