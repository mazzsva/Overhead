# Overhead

Fixed-cost tracker in SwiftUI, TCA, and Firestore.

## Core technologies

<table>
  <tr><td><b>Platform</b></td><td>iOS 27</td></tr>
  <tr><td><b>Language</b></td><td>Swift 6</td></tr>
  <tr><td><b>Interface</b></td><td>SwiftUI</td></tr>
  <tr><td><b>Architecture</b></td><td><a href="https://github.com/pointfreeco/swift-composable-architecture">The Composable Architecture</a></td></tr>
  <tr><td><b>Backend</b></td><td>Firebase</td></tr>
  <tr><td><b>Database</b></td><td>Cloud Firestore</td></tr>
  <tr><td><b>Authentication</b></td><td>Sign in with Apple</td></tr>
  <tr><td><b>Testing</b></td><td><a href="https://github.com/swiftlang/swift-testing">Swift Testing</a></td></tr>
</table>

## Quality gates

- **Tests:** 232 tests: 206 offline unit tests and 26 integration tests on Firebase emulators.
- **Integration:** The integration tests check the Firestore rules and the storage layer on every pull request.
- **CI:** GitHub Actions lints with `swift format --strict` and runs the full suite on each ready pull request.
- **Accessibility:** Every control has a VoiceOver label, and each amount reads as one value.
- **Localization:** Every string the app shows is ready for translation.

## Engineering decisions

**Rules that match the app.** The Firestore rules enforce the form's limits: a positive amount, a name of 1 to 100 characters, a supported currency, and savings within income. A bad write fails on the server, not only in the UI.

**Live sync.** The expenses and the budget each have one source of truth: a live Firestore listener backed by its local cache, so local changes appear at once, even offline, and sync to every other device.

**One reducer tree.** App state lives in a single tree of reducers instead of scattering across views. Navigation is part of that state, so the whole navigation graph can be inspected and tested from one place.

**No view touches Firebase.** Every effect crosses a client with live, preview, and test implementations, so previews render with no network and a test fails on any effect it doesn't override.

**Apple Account checks.** The app checks the Apple Account credential on launch and each time it becomes active, and it listens for revocations. Only a revoked credential signs the user out.

**Account deletion.** Deleting an account reauthenticates with Apple, deletes the Firestore data, revokes the token, then deletes the account. It times out after 60 seconds, and a failure after the revoke signs out.
