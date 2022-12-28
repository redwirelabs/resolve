# Resolve

Dependency injection and resolution at compile time or runtime.

Resolve is designed for swapping out dependencies in multi-target systems,
like embedded / IoT devices, where different hardware may be available depending
on which target the firmware is running on, or where physical hardware may be
missing all together when running the firmware on the host for development and
testing. That being said, Resolve also works for the traditional case of unit
testing, as the test environment is essentially just another type of target.

Resolve can be used in conjunction with mocks for testing, as they each have
their own advantages. Resolve has the benefit of not being linked to a process,
which means Resolve can be helpful for testing GenServers or other code that
runs in a process your test doesn't have direct access to. Resolve also allows
you to create throw-away anonymous modules for unit tests, rather than creating
named mock modules or factories.

## Installation

The package can be installed by adding `resolve` to your list of dependencies
in `mix.exs`:

```elixir
def deps do
  [
    {:resolve, "~> 0.0.1"}
  ]
end
```

## Usage

Include resolve in the module that requires dependency injection with
`use Resolve`. Any place in that module that might need a dependency injected
can then use `resolve(Module)` to allow another module to be injected. The
module passed to `resolve/1` will be used if another module isn't injected.

```elixir
defmodule MyInterface do
  use Resolve

  def some_command, do: resolve(__MODULE__).some_command
end 
```

### Configuration

Resolve can be configured in the project's `config.exs`.

**Opts**
- `compile` - `false` - Sets the mappings at compile time and doesn't start 
    the process that allows them to be modified at runtime. This method is
    more secure and more performant. Compiling is intended for production and
    runtime is intended for unit tests.
- `mappings` - `[]` - A two element tuple of the modules to map from and to:
    `{from, to}`

**Example**


```elixir
config :resolve,
  compile: true,
  mappings: [
    {OriginalModule, InjectedModule},
  ]
```

### Runtime

Dependencies can be injected at runtime with `inject/2`. This is intended for
unit testing, but not necessarily limited to it. Runtime mappings will be
less performant compared to compiled mappings, as each lookup goes through
a read-optimized ETS table.

```elixir
Resolve.inject(OriginalModule, InjectedModule)
```

Modules can also be defined directly in a block, which can be helpful if they
are only needed for certain tests.

```elixir
Resolve.inject(Port, quote do
  def open(_name, _opts), do: self()

  def close(_port), do: :ok

  def command(_port, _data), do: :ok
end)
```

### Reverting a mapping

If dependencies are resolved at runtime, any injected dependencies for a module
can be removed by calling `revert/1`. This removes any mappings for the module
from the lookup table.

```elixir
Resolve.revert(Module)
```
