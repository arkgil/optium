# Optium

Tiny library for validating arguments passed to your Elixir functions in keyword lists

[Take me straight to the installation!](#installation)

[Documentation](https://hexdocs.pm/optium)

## Rationale

How many times have you said to yourself: "Eh, I wish I could validate those arguments
passed in keyword lists using one function, instead of writing that stuff for every project I create.."?
Even if answer is 0, Optium might be just the thing you need!

I've started developing this library because of the reason above: too many times
I had to write functions which would validate arguments passed in keyword lists.
Optium aims to cover this use case using simple and clean API.

## Example

Optium uses so called schema, to determine how keyword list should be "parsed"
and validated, for example:

```elixir
%{port:    [required: true, validator: &is_integer/1],
  address: [required: true, default: {0, 0, 0, 0}]}
```

The schema above is quite self-explanatory: `:port` option is required,
and must be an integer. `:address` is required too, but it also has a default value assigned.

After you've created your schema, you can pass it along with some keyword list to
`Optium.parse/2` or `Optium.parse!/2`, and Optium will validate the keyword list
and tell you if something went wrong.

```elixir
iex> [port: 12_345] |> Optium.parse(schema)
# => {:ok, [port: 12_345, address: {0, 0, 0, 0}]}
iex> [port: 12_345, address: {127, 0, 0, 1}] |> Optium.parse(schema)
# => {:ok, [port: 12_345, address: {127, 0, 0, 1}]}
iex> [address: {127, 0, 0, 1}] |> Optium.parse(schema)
# => {:error, Optium.OptionMissingError{keys: [:port]}}
iex> [port: "12_345"] |> Optium.parse(schema)
# => {:error, %Optium.OptionInvalidError{keys: [:port]}}
```

And that's it! There is also "bang" version of `parse/2` (`parse!/2`) if you like
to raise those exceptions :boom:

For more detailed usage instructions, head to the [documentation](https://hexdocs.pm/optium)

## Installation

Just add to your Mix dependencies:

```elixir
{:optium, "~> 0.2"}
```

and

```
$ mix deps.get
```

## License

Copyright 2017 Arkadiusz Gil

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
