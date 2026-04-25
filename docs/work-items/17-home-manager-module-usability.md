Status: `done`
Suggested branch: `feat/fnox-hm-module-usability`
Priority: `low`

# Home Manager Module Usability

## Goal

Close two small gaps in the Home Manager module that cause friction for
downstream users.

## Why

### fnoxPath default

`mkSecretSpec { envVar = "FOO"; }` defaults `fnoxPath` to `envVar`, but the
`secrets` submodule in the Home Manager module does not apply that same
default. Users authoring `programs.fnox.wrappedCommands` must always write
both fields explicitly even when they are identical:

```nix
secrets = [
  { envVar = "GITHUB_TOKEN"; fnoxPath = "GITHUB_TOKEN"; }  # redundant
];
```

The module should default `fnoxPath` to `envVar` when omitted.

### Assertion error messages

The module currently asserts:
- at least one age recipient
- no duplicate `envVar` names in a wrapped command
- every `fnoxPath` referenced in `wrappedCommands` is declared in
  `secretDefinitions`

These assertions fire with NixOS evaluation errors that can be confusing
without context. Each message should include the field name and a one-line
hint pointing at the fix.

## Scope

- add a `default = config.envVar;` to the `fnoxPath` option in the `secrets`
  submodule so it mirrors `mkSecretSpec`
- review and improve assertion messages for all three existing assertions
- update `examples/home-manager-minimal.nix` if the new default changes the
  recommended style

## Non-Goals

- adding new assertions beyond the existing three
- validating that referenced package attributes exist in `pkgs`

## Validation

- omitting `fnoxPath` when it equals `envVar` no longer causes an assertion
  failure
- assertion messages contain the field name and a clear fix hint
- existing checks still pass
