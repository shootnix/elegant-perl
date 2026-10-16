<div align="center">

# Elegant::Perl

### Explicit Contracts. Small Objects. Fewer Hidden Conventions.

A framework for object-oriented Perl code with required fields, generated constructors, and enforceable contracts.

[![CPAN version](https://img.shields.io/cpan/v/Elegant-Perl?label=CPAN)](https://metacpan.org/release/Elegant-Perl)
[![Perl](https://img.shields.io/badge/Perl-5.32%2B-39457E?logo=perl&logoColor=white)](https://www.perl.org/)
[![License](https://img.shields.io/badge/license-not%20specified-lightgrey)](#license)

</div>

> **Status:** Early version `0.01`. The API and conventions are still subject to change.

## What It Is

`Elegant::Perl` is a set of conventions and tools for small Perl applications that benefit from explicit boundaries between objects and their contracts. It is neither a new language nor a static type system: modules remain ordinary Perl code, and some errors are detected when a class is loaded or a method is called.

It includes:

- `Elegant::Perl` — a class DSL with `field`, `implements`, `cap`, private state, and an automatically generated `new()`;
- `Elegant::Perl::Contract` — declarations of methods, argument types, and return types;
- a set of Perl::Critic policies and the `elegant-perl check` command for checking files that use Elegant::Perl.

## What It Provides

- **Consistent object construction.** `new()` accepts named arguments, rejects unknown and duplicate names, requires a value for every declared field, and validates explicitly declared field types.
- **Encapsulated state.** Fields are read through the package function `value($self, 'field')`, rather than by accessing an object's hash. The object itself does not store fields in a hash accessible to calling code.
- **Explicit contracts.** A class lists the interfaces it implements, and the framework checks method completeness and compatibility when the class definition is finalized.
- **Runtime checks.** For contract methods with `:Expects(...)` and `:Returns(...)`, the number and types of arguments and the return value are checked.
- **Opt-in language features.** Import tags enable strict mode, the Perl 5.32 feature bundle, signatures, the `isa` operator, and compatibility implementations of `try`/`defer`.
- **Consistent style.** Perl::Critic policies detect certain constructs that conflict with the Elegant::Perl model.

## Quick Start

A contract can be declared in a separate module:

```perl
package Example::Contract::Greeter;

use v5.32;
use Elegant::Perl::Contract;

sub greet
    :Builder
    :Expects(Str)
    :Returns(Str);

1;
```

A class implements the contract and declares its fields. Public methods access private values through `value()`:

```perl
package Example::Greeter;

use v5.32;
use Elegant::Perl qw(:modern :signatures);

implements 'Example::Contract::Greeter';
field 'prefix';

sub greet ($self, $name) {
    return value($self, 'prefix') . $name;
}

1;
```

After loading these modules, the class can be used as follows:

```perl
my $greeter = Example::Greeter->new(prefix => 'Hello, ');
say $greeter->greet('world');
```

If a contract specifies `:Expects(Str) :Returns(Str)`, the implementation automatically receives runtime checks for one string argument and a string return value. Manipulators use `:Manipulator`, which implies `:Returns(Void)` and does not return a value.

### Contracts and Types

Every contract method must have exactly one semantic annotation:

- `:Builder` — the method returns a value and must specify exactly one type through `:Returns(Type)`;
- `:Manipulator` — the method returns no value; `:Returns(Void)` is implied.

Arguments are declared using `:Expects(Type, Type, ...)`. Supported types are `Scalar`, `Object`, `Self`, `Bool`, `Int`, `Num`, `Str`, `Void` (only as a return marker), an Elegant::Perl contract name, or a generated cap type name. `Self` means the exact implementing class, `Object` means any blessed object, and a contract name means an object implementing that contract. Type checks apply to types declared in the contract.

### Field Types and Constructor Arguments

`field` accepts an optional type name. The constructor validates the supplied value:

```perl
field 'customer' => 'Example::Customer::Cap::Billing';
field 'amount'   => 'Num';
field 'greeter'  => 'Example::Contract::Greeter';
field 'label'; # no specific type restriction
```

A field typed as a cap requires an explicitly issued cap:

```perl
my $billing = Example::Billing->new(
    customer => $customer->as_cap('Billing'),
    amount   => 100,
    greeter  => $greeter,
    label    => 'Invoice',
);
```

A full `Example::Customer` object, a different cap, or a forged blessed object does not satisfy the `Example::Customer::Cap::Billing` type. There is no automatic conversion to a cap.

Supported types are `Scalar`, `Object`, `Self`, `Bool`, `Int`, `Num`, `Str`, contract names, and generated cap types—the same value types supported by method contracts. An arbitrary class name is not a valid type; `Void` is not allowed. Type validators are created when the class is finalized, and values are checked when `new()` is called.

All fields remain required. Regardless of whether a type is specified, `undef` and unblessed references are not allowed. Declaring `field 'label'` preserves the existing behavior: it accepts any defined scalar or blessed object. Checks are performed at runtime; there is no static typing.

### Cap: A Restricted Object Interface

Cap is short for *capability*: a named set of capabilities associated with a particular object. A class declares a `cap` as a hash of public method names mapped to their implementing closures, and `as_cap()` issues an object exposing those capabilities. The framework generates a distinct type, and each closure receives the original object as `$self`. Public method names are independent of internal field names:

```perl
package Example::Customer;

use Elegant::Perl;

field 'name';
field 'billing_address';
field 'password_hash';

cap 'Billing' => {
    email => sub ($self) { value($self, 'billing_address') },
    greeting => sub ($self, $prefix) { $prefix . value($self, 'name') },
};
cap 'Public' => {
    name => sub ($self) { value($self, 'name') },
};
```

Code holding the full object explicitly issues a cap:

```perl
my $customer = Example::Customer->new(
    name            => 'Alice',
    billing_address => 'alice@example.test',
    password_hash   => 'secret',
);

my $billing = $customer->as_cap('Billing');
say $billing->email;                # alice@example.test
say $billing->greeting('Hello, '); # Hello, Alice
# $billing->password_hash;         # error: method not available
# $billing->as_cap('Public');      # error: a cap cannot issue other caps
```

The `Example::Customer::Cap::Billing` type can be used in contracts:

```perl
package Example::Contract::InvoiceSender;

use Elegant::Perl::Contract;

sub send_invoice
    :Manipulator
    :Expects(Example::Customer::Cap::Billing);
```

The recipient accepts only the issued cap: the full `Example::Customer` object, another cap, or a forged blessed object fails validation. `:Returns(Example::Customer::Cap::Billing)` is checked in the same way. No separate module is needed for the generated type: the framework loads the owner's module when resolving the type.

Cap rules:

- A declaration accepts exactly a name and a nonempty hash of methods. Each value must be a `CODE` reference. The old field-list syntax is not supported.
- Cap names and method names must be identifiers without `::`. Conflicts with infrastructure methods (`new`, `as_cap`, `DESTROY`, `can`, and others) are prohibited. The `Class::Cap::Name` namespace is reserved for the framework. Duplicate hash keys follow ordinary Perl rules: the last value wins.
- A cap exposes only its declared methods. It does not inherit methods from its owner and has no public constructor. The supplied hash is copied at declaration time; subsequent changes to it do not alter the cap interface.
- Closures receive the original object followed by the call arguments. Perl signatures may constrain the arguments. Calling context (scalar/list/void), results, and exceptions are passed through unchanged; closure return types are not implicitly checked.
- The underlying data is not copied. A cap keeps the original object alive until the cap is released; issuing a cap again creates a separate cap object.
- Closures are trusted class implementations: they can read private fields, invoke behavior, and return objects. The author is responsible for exposed data and side effects. To restrict access to a nested object, a closure may return that object's cap. Deep immutability is not guaranteed.
- Any code holding the full object can issue any declared cap. There are no separate lists of authorized recipients.
- The available methods are fixed by the declaration. `:Expects`, `:Returns`, and explicitly typed fields validate cap type membership at runtime. Closure access to private fields is checked by `value()` at runtime; field access is not statically analyzed.

A cap is an interface belonging to a specific class, not a subclass of its implementation. Identical sets of methods declared by different classes produce different types. Renaming an internal field requires updating the closures that reference it, while keeping the cap's public method names unchanged.

### Import Tags

Without arguments, `use Elegant::Perl` enables `:all`. To avoid enabling features unnecessarily, select a tag:

| Tag | Imports |
| --- | --- |
| `:core` | `strict`, `warnings`, `utf8` |
| `:features_532` | Perl 5.32 feature bundle |
| `:signatures` | subroutine signatures |
| `:isa` | `isa` operator |
| `:try` / `:defer` | corresponding `Feature::Compat` modules |
| `:modern` | `:core` and `:features_532` |
| `:compat` | `:try` and `:defer` |
| `:all` | all of the above; enabled by default |

## Limitations and Non-Goals

These restrictions are intentional, but they will not suit every Perl project:

- **No implementation inheritance.** Contracts and composition are used instead.
- **No custom constructors.** `new()` is generated by the framework; all declared fields are required, with no default values or optional fields.
- **`undef` and unblessed references are not valid field values.** Defined scalars and blessed objects are permitted.
- **No deep immutability.** The state table itself cannot be modified through ordinary object access, but an object stored in a field may have mutable internal state.
- **No static typing.** Contract checks occur at load time or during calls; they do not prove program correctness.
- **Return-value checks are not possible in every Perl context.** A return value cannot be validated when a method is invoked in void context.
- **Perl::Critic policies do not prove correctness.** They provide a limited set of stylistic and structural checks, not a general-purpose security analyzer.

## Checking a Project

Constructor errors and contract method invocation errors point to the call site in user code. Field type and contract errors detected during class finalization (including in `CHECK`) point to the recorded declaration site. Errors raised inside user-defined closures and methods retain their original messages and locations.

Dependencies are listed in the distribution metadata. From a checkout, run the tests with:

```sh
prove -Ilib -r t
```

Run the Perl::Critic policies with:

```sh
perl -Ilib bin/elegant-perl check lib t
```

Without paths, the command checks `lib`. Files with the `.pm`, `.pl`, and `.t` extensions are supported.

## Installation

After the release is published to CPAN:

```sh
cpanm Elegant::Perl
```

For development from a checkout, first install the distribution dependencies, then run `perl Makefile.PL` and `make test`.

## Compatibility

Requires Perl **5.32 or later**.

## License

MIT
