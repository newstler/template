# sqlite-vec binaries

Loadable SQLite extension for vector search. Zero runtime dependencies.

## Source

https://github.com/asg017/sqlite-vec

## Version

v0.1.9

## License

Apache-2.0 and MIT (dual-licensed). Binaries are redistributable.

## Supported platforms

- `linux-x86_64/vec0.so`
- `linux-aarch64/vec0.so` (Kamal on aarch64 hosts)
- `darwin-arm64/vec0.dylib` (Apple Silicon dev machines)

Intel macOS is not included — run on Rosetta if needed. Windows is out of scope.

## Upgrading

1. Download the new release tarballs from the source above.
2. Replace the three binary files in place.
3. Update the Version above.
4. Run `bin/rails test` locally + `bin/ci` before committing.
