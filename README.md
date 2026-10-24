# Overhead

Expense tracker in SwiftUI, TCA, Firestore, and Swift Charts.

<img src="https://github.com/user-attachments/assets/28ce5ec8-3945-4bb9-84c2-1fc7a53645e4" alt="The sign-in screen, with the Sign in with Apple button" width="32%"> <img src="https://github.com/user-attachments/assets/c4140c3d-24bc-459e-8d50-6440c17ccb20" alt="The home screen, with the list of entry cards and the sync status" width="32%"> <img src="https://github.com/user-attachments/assets/42c3037b-10ab-4204-aec1-811261fd6bc9" alt="An entry detail screen, with the term and its definition" width="32%">

## Core technologies

<table>
  <tr><td><b>Platform</b></td><td>iOS 26</td></tr>
  <tr><td><b>Language</b></td><td>Swift 6</td></tr>
  <tr><td><b>Interface</b></td><td>SwiftUI</td></tr>
  <tr><td><b>Architecture</b></td><td><a href="https://github.com/pointfreeco/swift-composable-architecture">The Composable Architecture</a></td></tr>
  <tr><td><b>Backend</b></td><td>Firebase</td></tr>
  <tr><td><b>Database</b></td><td>Cloud Firestore</td></tr>
  <tr><td><b>Authentication</b></td><td>Sign in with Apple</td></tr>
</table>

## Quality gates

- **Tests:** 86 [Swift Testing](https://github.com/swiftlang/swift-testing) tests cover every reducer, and none touch the network.
- **CI:** GitHub Actions lints and runs the full suite on every pull request that is ready for review.
- **Accessibility:** Every control has a VoiceOver label, and each entry card reads as one element.
- **Localization:** Every string the app shows is ready for translation.

## Engineering decisions

**Live sync.** The expenses and the budget each have one source of truth: a live Firestore listener backed by its local cache, so changes appear at once on every device and never wait for the network.

**One reducer tree.** Every screen pairs a reducer with a view of the same name, and the app holds them in a single tree instead of scattering state across views. Navigation is a property on that state, not a flag a view owns, so the whole navigation graph can be inspected and tested from one place.

**No view touches Firebase.** Every effect crosses a client that has a live implementation and a preview one, so previews render with no network and any effect can be swapped out under test.

**Account deletion.** Deleting an account reauthenticates the user with Apple, revokes the Apple token, then deletes the account and its Firestore data.
