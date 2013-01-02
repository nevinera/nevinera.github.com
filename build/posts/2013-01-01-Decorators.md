* title: Decorators
* subtitle: Putting your models on a strict diet

In the Rails world, the 'Decorator' patterns has become basically synonymous with
the 'Presenter' pattern, and almost always uses one gem: Draper. That's a
serious shame, because decorators are much older and much more versatile than
presenters, and can solve many problems you may not have known you had.

A decorator, in the OOP sense, is an object that delegates any method it doesn't
specifically implement to another object - when you use a decorator, you 'decorate'
some model with the capabilities implemented on the decorator. This is an effective
way to organize code when you have significant functionality that is limited in
scope. A presenter is a special case, a decorator in which the scope is 'presentation'.

It's difficult to show a code example of something that should be refactored with
a decorator, because I don't feel like 8 pages of model code is appropriate to
a programming post, so just pretend that this model is complex enough to be
problematic:

```ruby
class Report < ActiveRecord::Base
  has_many :topics
  belongs_to :user

  def self.active
    where(:state => 'active')
  end

  def viewable?
    self.state == 'active' || self.state == 'archived'
  end

  ## these are used in the import process
  def build_csv
    # ....
  end

  def upload_to_s3
    # ....
  end

  def clean_up
    if self.backed_up?
      # ....
    end
  end
end
```

Those last three methods are limited in scope - they are only used in the `ImportJob`
and `BackupJob` (job classes for the queueing system of your choice), and are
therefore prime candidates for a decorator refactoring. Ruby comes with an
excellent class called `SimpleDelegator` that is a full decorator implementation.
Our decorator class will look like this:

```ruby
# I put this in app/decorators/report_decorator/import.rb
class ReportDecorator::Import < SimpleDelegator
  def build_csv
    # ....
  end

  def upload_to_s3
    # ....
  end

  def clean_up
    if self.backed_up?
      # ....
    end
  end
end
```

We could use this immediately:

```ruby
class ImportJob << ApplicationJob
  def perform
    r = Report.find(@report_id)
    @report = ReportDecorator::Import.new(r)

    # do stuff with it ....
  end
end
```

And it's not bad! But I demand *elegance* - this `ReportDecorator::Import.new(r)`
stuff is verbose and unattractive. It's important to be explicit that you're
using a decorator - that's one of the main points of the pattern - but we can be
explicit without being quite so noisy.

```ruby
class Report
  PRESENTERS = {
  :import => ReportDecorator::Import
  }

  def using(deck)
    p = PRESENTERS[deck]
    p.new(self)
  end
end

class ImportJob << ApplicationJob
  def perform
    r = Report.find(@report_id).using(:import)
    # do stuff with it ....
  end
end
```

That's much better! Now I can use the natural `report.s3_path` in my backup job,
`report.write_csv!` in my export job, and `report.serializable_hash(...)` in my
json endpoints *without* having a 40 page model. We can separate the concerns
of the report model from each other without any danger that they become entangled
again later. All of the cleanliness of `app/concerns` without any of its traps.

It does have its own traps, of course, though they mostly indicate a code smell.
A decorated report has type `ReportDecorator::Import` for example, not `Report`.
Anything that checks the model's class will be confused by that. The most
important of those for my applications is CanCan, our resource authorization gem.
The authorization calls consult a resource table based on class to determine
accessibility. The simplest answer is to expose the original object:

```ruby
class ApplicationDelegator < SimpleDelegator
  def model
    m = self
    depth = 0
    while depth < 100 and m.respond_to?(:__getobj__)
      m = m.__getobj__
      n += 1
    end
  end
end
```

`__getobj__` is provided by `SimpleDelegator`, but if you have decorated with more
than one it won't suffice. The subtler answer is that checking the class of an
object is inappropriate, even using `is_a?` to handle subclassing. The appropriate
solution is to add the capability to CanCan to allow you specify the authorization
class for a model in a method called `authorization_class` and configure CanCan
to use that method instead of the class itself. I intend to pull-request that
feature into CanCan, but intentions are worth roughly their weight in gold.


### Presenters

Presenters are a special case of decorator that is somewhat specific to web
applications - the 'Presenter Pattern' is fairly loosely defined, and doesn't
really map to a decorator necessarily, but it's been gaining some traction in
Rails that way. The problem it tries to solve is that, in Rails and many other
(similar) application frameworks, there's a disorganized layer of glue code between
the data and the templates. In some systems those would *be* the views, but in
Rails they are the 'helpers'. They live in an effectively global namespace,
the 'helper context', which is accessible from templates and controllers, and
they are universally the least organized and modular part of a Rails project.

Draper is a ruby gem that attempts to solve this problem using decorators -
a `Draper::Base` (which I believe changed names to `Draper::Decorator` recently)
is a decorator which has the significant additional benefit of a `self.h` method
that returns the helper context, allowing you to do anything you could do in a
helper (render a partial, construct content, format data, etc) in a presenter
straightforwardly.

What makes these presenters different from helpers is that they are explicit -
instead of calling `pretty_report_name(report)`, you just call `report.pretty_name`,
after decorating with the `report_presenter`. Draper is set up rather assuming a
single presenter per model, but there is no need for that - if some presentation
code is narrow in scope, you should have another presenter that addresses that
scope: `ReportPresenter`, `ReportPresenter::Admin`, and `ReportPresenter::Comparison`
are all separate presenters that are useful in different contexts.

Because these are so similar to the simpler decorators I described above, I put
them in the same place - my `app/decorators/` directory looks like this:

```text
report_decorator.rb
report_decorator/import.rb
report_decorator/serialization.rb

report_presenter.rb
report_presenter/admin.rb
report_presenter/comparison.rb
```

But presenters are fairly specific in scope, and are largely used by a different
set of people that normal decorators, so I gave them their own syntax. You decorate
a report with its presenters like:

```ruby
report.presenter
report.presenter(:admin)
report.present_for_admin
reports.map(&:present_for_admin)
```

(All of my decorators also get a method to themselves - `using_serialization`,
`present_for_admin` - because that makes them easier to use on collections via
`map`.)

One thing to be careful of with Draper though - the draper decoraters internally
define `to_json` for some reason, so you need to add an application_presenter to
inherit from in all of your presenters like so:

```ruby
class ApplicationPresenter < Draper::Base
  def to_json(*args)
    model.to_json(*args)
  end
end
```

I will probably talk about this more in the future - we only starting using them
in real code a few weeks ago, so the subtler problems and benefits from them
haven't cropped up yet. I am very pleased with the effects decorators have had
on the backend codebase of the product I have been working with most - we'll
have to see what our frontend developers and designer think of it soon.
