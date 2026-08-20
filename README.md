# resource_core

`resource_core` owns the field spec for a model — what its attributes are,
and how each should be treated — plus every extension point a renderer built
on top of it needs: field types, themes, detection, error routing, and value
formatting. It renders nothing itself.

[`resource_form`](https://github.com/bduc/resource_form) is the first
renderer built on `resource_core`: a Rails form builder. A table renderer is
planned next, reading the same resource classes. Nothing here depends on
either renderer, or on any consuming application's models — the examples
below use a small `Author` / `Book` / `Publisher` / `Review` domain (the same
one the test suite's dummy app uses).

## Installation

Add it to your Gemfile — directly if you're building a renderer, or
transitively by depending on one that already requires it (`resource_form`
does):

```ruby
gem "resource_core"
```

## Public extension surface

Everything below this line is the contract other code is written against.
**It changes only on a major version bump** — `resource_form` today, a table
renderer next, and at least one more application are expected to depend on
none of this moving under them:

- `ResourceCore::BaseResource.field`, `.field!`, `.fields`,
  `.model_class_name`, `.model_class`
- `ResourceCore.config` (`.theme`, `.base_class`, `.resource_class_suffix`,
  `.lookup_label_methods`) and `ResourceCore.configure`
- `ResourceCore.resolve`
- `ResourceCore.register_renderer`
- `ResourceCore.register_field_type` / `ResourceCore.field_type` /
  `ResourceCore.field_types`
- `ResourceCore.register_namespace`
- `ResourceCore.detect`
- `ResourceCore.register_theme` / `ResourceCore.theme_chain`
- `ResourceCore.register_error_rule` / `ResourceCore.consumed_error_names`
- `ResourceCore.register_format` / `ResourceCore::Value.raw` /
  `ResourceCore::Value.display`
- `ResourceCore.lookup_label`

Everything else — `ResourceCore::Registry`'s internals, `FieldType`,
`Theme`, the shape of `ResourceCore::Detection`'s column-type mapping — is
implementation detail. It can change in a minor or patch release; nothing
outside this gem should call it directly.

Registration (`register_*`, `detect`) happens at boot, in an initializer.
A typo there raises immediately, instead of at render time in whichever view
happens to hit it first.

## `ApplicationResource` and `ResourceCore.config.base_class`

Apps subclass `ResourceCore::BaseResource` **once**, the way `ApplicationRecord`
works — no renderer contributes a base class of its own, because a form base
class would be the wrong parent for a table:

```ruby
# app/models/application_resource.rb
class ApplicationResource < ResourceCore::BaseResource
end
```

`ResourceCore.config.base_class` names that class — `"ApplicationResource"` by
default — and `ResourceCore.resolve(model_class)` is how a renderer turns a
model into its resource: the conventionally named class if one exists
(`BookResource` for `Book`, via `config.resource_class_suffix`), otherwise an
anonymous subclass of `config.base_class`:

```ruby
ResourceCore.resolve(Review).model_class_name  # => "Review" — no ReviewResource defined
ResourceCore.resolve(Review) < ApplicationResource  # => true
```

`base_class` is held as a **String**, constantized on demand, not the class
itself:

```ruby
ResourceCore.config.base_class = "Admin::ApplicationResource"
```

A captured constant would go stale the moment Rails reloads the class in
development; a name re-resolves every time.

## `field`, `field!`, `fields`

`field` declares or overrides a field on a resource class. Detection already
ran by the time your `field` calls execute, so most calls are adjusting a
detected spec rather than inventing one from nothing:

```ruby
# app/resources/book_resource.rb
class BookResource < ApplicationResource
  field :synopsis, as: :textarea, hint: "Shown on the detail page"
  field :isbn, nil   # field(name, nil) removes a field entirely
end

BookResource.fields[:synopsis][:as]    # => :textarea
BookResource.fields.key?(:isbn)        # => false
```

`field!` does the same thing but **only if the attribute is already a
field** — it is how you adjust a detected spec without accidentally
inventing a field when the underlying column gets renamed away:

```ruby
class BookResource < ApplicationResource
  field! :title, label: "Titel"           # :title is a real column — this applies
  field! :nonexistent, label: "Ignored"   # not a column or association — silently ignored
end

BookResource.fields[:title][:label]        # => "Titel"
BookResource.fields.key?(:nonexistent)     # => false
```

`fields` returns the full `{ name => spec }` hash — every detected column and
association, plus your overrides. `model_class_name` / `model_class` derive
from the resource class's own name (`BookResource` → `"Book"`, by stripping
`config.resource_class_suffix`); set `model_class_name=` explicitly on an
anonymous class that has none.

An unknown option on `field` or `field!` raises `ArgumentError` naming both
the bad key and the full allowed list — see [Option
validation](#option-validation) below for what makes a key legal.

## `register_renderer`

Declares a renderer's name and the options every one of its field types
accepts, whatever the type:

```ruby
ResourceCore.register_renderer :form,
  options: %i[placeholder required readonly disabled prepend append]
```

`register_field_type` checks its `renderers:` list against this registry and
raises immediately if a type names a renderer that was never registered — so
register renderers before the field types that belong to them.

## `register_field_type`

A field type is a name, the renderer(s) it renders for, and everything a
partial needs to know about it:

```ruby
ResourceCore.register_field_type :money,
  renderers: [ :form ],              # which renderer(s) this type belongs to
  options:   %i[currency],           # extra option keys this type accepts, on top of the core and renderer sets
  defaults:  { currency: "EUR" },    # merged under the resource's spec and the call site's options
  partial:   "money_input",          # defaults to the type's own name — "money" here, if omitted
  wrapper:   true                    # false for a type that renders its own label (a checkbox, say)
```

```ruby
type = ResourceCore.field_type(:money)
type.options    # => [:currency]
type.defaults   # => { currency: "EUR" }
type.partial    # => "money_input"
type.wrapper?   # => true
```

`options:` and `defaults:` default to `[]` and `{}`; `partial:` defaults to
the type's own name (so most registrations omit it); `wrapper:` defaults to
`true`. Re-registering the same name replaces it — that is how an app
overrides an engine-supplied type. `ResourceCore.field_types(renderer:)`
lists every type for one renderer, or all of them if `renderer:` is omitted.

## `register_namespace`

A namespace is a per-renderer group of spec keys, reserved for a mode a
renderer hasn't built yet — a table's `index:` column options, a detail
page's `show:` formatting, a search form's `filter:` operator:

```ruby
ResourceCore.register_namespace :index, %i[sortable width]
```

On a field, a namespace's value is a Hash of *its own* registered keys, or
`false` meaning "excluded from that renderer":

```ruby
class BookResource < ApplicationResource
  field :title, index: { sortable: true, width: 180 }
  field :synopsis, index: false
end

BookResource.fields[:title][:index]     # => { sortable: true, width: 180 }
BookResource.fields[:synopsis][:index]  # => false
```

An unknown key inside the Hash raises the same way an unknown top-level
option does, naming the namespace and what was allowed inside it.

## `detect`

Registers a block in the detection chain that field-type inference walks
before falling back to the column's SQL type:

```ruby
ResourceCore.detect { |name, column| :money if name.to_s.end_with?("_cents") }

ResourceCore::Detection.field_type_for(:price_cents, nil)  # => :money
```

Detectors run **newest-first** (`register_detector` unshifts) — an app's
detector, registered after the engines', wins over an engine's detector for
any name the two disagree on. Return a falsy value to defer to the next
detector; the column-type mapping (`string` → `:text`, `integer` / `bigint`
/ `decimal` / `float` → `:numeric`, `boolean` → `:boolean`, and so on) is the
floor a detector can never fail to hit, so there is always an answer. `column`
is `nil` for a virtual attribute that isn't a real database column (a
Devise-style `password` accessor, for instance) — a detector that only reads
`name` still applies.

## `register_theme` and how the parent chain resolves

A theme names itself and, optionally, a parent it falls back to:

```ruby
ResourceCore.register_theme :daisyui
ResourceCore.register_theme :acme, parent: :daisyui

ResourceCore.theme_chain(:acme)  # => [:acme, :daisyui]
```

A renderer walks this chain, in order, and uses the **first partial that
exists** for the current field type — so a consumer's theme only has to
supply the partials that actually differ from its parent, not a full copy of
every one. Chains nest more than one level (`ResourceCore.theme_chain(:leaf)`
returns every ancestor up to the root). Registering a theme whose `parent:`
isn't registered yet raises immediately, and so does closing a cycle —
neither waits for the first render to fail.

## `register_error_rule`

A rule maps a field name (and its spec) to the *other* attribute names it
should also report errors for — the mechanism behind a `:author_id` field
surfacing a `validates :author, presence: true` failure without any
per-field configuration:

```ruby
ResourceCore.register_error_rule do |name, _spec|
  name.to_s.sub(/_id\z/, "").to_sym if name.to_s.end_with?("_id")
end

ResourceCore.consumed_error_names(:author_id, {})  # => [:author_id, :author]
```

A field always consumes its own name; rules and the spec's own
`consume_errors:` option add to that list, and duplicates collapse. **Rules
are rescued individually** — a bad assumption in one rule (a missing
association, a spec key that isn't there) contributes nothing and is logged,
but does not take the render, or any other rule, down with it.

## `register_format` and `Value.display`

`ResourceCore::Value` reads an attribute and turns it into something
displayable, so two renderers don't reinvent (and disagree about) what
`format: :currency` means:

```ruby
ResourceCore.register_format(:euro) { |value, _record, _spec| "€ #{'%.2f' % value}" }

book = Book.new(price: 12.5)
ResourceCore::Value.display(book, :price, { format: :euro })  # => "€ 12.50"
```

`Value.raw(record, name)` just reads the attribute (`nil` if the record
doesn't respond to it). `Value.display` formats it: **`nil` always formats to
`""`, without the formatter ever running** — a formatter written for a number
should never have to guard against being handed `nil`. A `format:` that isn't
registered raises `ArgumentError` rather than silently falling back to
`to_s`; a callable passed directly as `format:` is used as-is, no
registration required.

## Option validation

`field` and `field!` raise on an unknown option rather than ignoring it — a
silently dropped option looks like the engine ignoring your intent, and is
usually a typo. A key is legal if any of these is true:

1. It's a **core option**, accepted on every field regardless of type or
   renderer: `as`, `label`, `hint`, `partial`, `format`, `unit`,
   `consume_errors`, `class_name`, `polymorphic`.
2. A **registered renderer** declared it (`register_renderer`'s `options:`)
   — shared by every type belonging to that renderer.
3. The field's own **type** declared it (`register_field_type`'s
   `options:`).
4. It **names a registered namespace** (`register_namespace`) — in which
   case its value must be a Hash of that namespace's own keys, or `false`.

Anything else raises, naming both the unknown key and everything that was
allowed for that field.

## Configuration

```ruby
ResourceCore.configure do |c|
  c.theme = :daisyui
  c.base_class = "ApplicationResource"                              # a String — see above
  c.resource_class_suffix = "Resource"
  c.lookup_label_methods = %i[lookup_label display_name full_name name]
end
```

`lookup_label_methods` is the convention chain `ResourceCore.lookup_label`
tries, in order, to label a record already selected in a lookup field — a
field's own `label_method:` wins over all of them, and `to_s` is the last
resort:

```ruby
class Author < ApplicationRecord
  def lookup_label
    "#{name} (##{id})"
  end
end
```

Have the matching lookup/search endpoint return the same string, so a
preselected option's label doesn't change between picking a record and
reopening the form.
