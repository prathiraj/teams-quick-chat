# Repository instructions

After making repository changes:

1. Update documentation when behavior, UI, configuration, storage format, or release behavior changes.
2. Run the relevant local validation (.NET 9 SDK for Windows WinForms changes; `swift test` and `./macos/scripts/package_macos.sh` for macOS Swift changes).
3. Bump the app version in `TeamsQuickChat.csproj`.
4. Commit and push changes to `master`.
5. Verify the GitHub Actions release workflow is triggered for the pushed commit.
