Status: `done`
Suggested branch: `test/fnox-wrapper-runtime-behavior`
Priority: `high`

# Wrapper Runtime Tests

## Goal

Add behavior-oriented tests for wrapper success/failure paths and seed fallback
behavior.

## Tasks

- cover non-zero exit when `fnox get` fails
- cover expected env export behavior on success
- cover unreadable or empty seed sources falling through cleanly

## Validation

- tests fail before a regression reaches users
