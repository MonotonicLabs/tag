# Contributing

Thanks for taking the time to contribute!

## Development

### Requirements

- macOS 15+
- Xcode (open `tag.xcodeproj`)

### Build

- Xcode: open `tag.xcodeproj` and run the `tag` scheme.
- CLI: `make build`

### Tests

- Unit tests: `make test`
- Integration tests: `make test-integration`

If you're running in CI (or locally without signing set up), disable code signing:

- `make test CI=1`
- `make test-integration CI=1`

## Notes

- Some features (Finder comments, “Open in Terminal”) require macOS Automation permissions.
- The background scheduler is implemented as a per-user LaunchAgent and runs the app executable with `--run-once`.
