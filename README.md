# LabelLens

A small iOS app (SwiftUI) that uses the camera to scan ingredient labels and flag
keywords the user has listed. It's a general-purpose keyword finder for ingredient
labels — not framed around any specific condition — and a convenience aid, not a
substitute for reading labels carefully. (The Xcode project/target are still named
`AllergyScanner` internally — see **Project structure** — only user-facing text and the
bundle ID were rebranded; a full project rename is a separate step if you want it.)

## How it works

1. **Home screen** ([HomeView.swift](AllergyScanner/HomeView.swift) /
   [HomeViewModel.swift](AllergyScanner/HomeViewModel.swift)) — the user maintains a list
   of keywords (free-text, e.g. "peanuts", "palm oil", "red 40"), persisted to
   `UserDefaults`.
2. **Scanner** ([ScannerView.swift](AllergyScanner/ScannerView.swift) /
   [CameraPreview.swift](AllergyScanner/CameraPreview.swift)) — opens a live camera feed
   in a full-screen sheet.
3. **OCR + matching** ([TextScannerService.swift](AllergyScanner/TextScannerService.swift))
   — runs Vision's `VNRecognizeTextRequest` on camera frames, normalizes the recognized
   text, and checks it against each keyword's search phrases (see below). Matches are
   drawn as red boxes over the offending text and listed as `⚠️` labels, showing the
   specific phrase that triggered the match when it's an alias rather than the keyword's
   own name (e.g. "⚠️ Milk — found: whey").
4. **Alias/derivative matching**
   ([AllergenMatcher.swift](AllergyScanner/AllergenMatcher.swift))
   — expands a user keyword like "milk" into the ingredient names that actually appear
   on labels for it (e.g. "whey", "casein", "lactose"), and does word-boundary phrase
   matching so multi-word keywords ("tree nuts") and near-miss words ("buckwheat" vs.
   "wheat") are handled correctly.
5. **Disclaimer** ([DisclaimerView.swift](AllergyScanner/DisclaimerView.swift)) — a
   full-screen, must-accept notice shown before first use (see **Legal / liability**
   below), re-readable anytime via the "Disclaimer & Limitations" link on the home
   screen.
6. **Ads + Remove Ads purchase** — see **Ads & in-app purchase** below.

## Recent scanning improvements

The original matcher only tokenized text into single words and compared them
case-insensitively to the exact allergen string (plus a naive singular/plural check).
That meant:

- Multi-word allergens (e.g. "tree nuts") could never match, since no single token ever
  equals a multi-word phrase.
- Common ingredient names for an allergen (whey/casein for milk, groundnut for peanut,
  gluten for wheat, shrimp/crab for shellfish, etc.) weren't recognized at all.
- Box highlighting used plain substring matching, which could flag unrelated words that
  merely contain the allergen as a substring (e.g. "nutmeg" for "nut").

`AllergenMatcher` now expands each allergen into a set of search phrases (itself, its
singular/plural form, and known aliases/derivatives) and matches them against scanned
text with word-boundary–aware regex, both for detection and for box highlighting.

**Highlight box position/size** ([CameraPreview.swift](AllergyScanner/CameraPreview.swift),
[TextScannerService.swift](AllergyScanner/TextScannerService.swift)) — three compounding
bugs made the red box land in the wrong place and look oversized/wrongly-shaped on a real
device (the simulator has no camera, so none of this was catchable without a physical
device):
- The preview used `.resizeAspect` (letterboxed, black bars), but the box math assumed
  the camera image filled the view edge-to-edge — any letterboxing threw off both
  position and scale. Fixed by switching to `.resizeAspectFill` (fills the screen, like
  any normal camera UI).
- Vision returns one bounding box per recognized *line* of text, so a match anywhere in
  a long ingredient line highlighted the entire line. Fixed by locating the matched
  phrase's exact position within that line via `VNRecognizedText.boundingBox(for:)` and
  drawing a box around just that word/phrase, falling back to the whole line only if the
  precise range can't be located.
- The trickiest one: `TextScannerService` tells Vision to read the sensor's raw
  (landscape) buffer as portrait via an orientation *hint*
  (`VNImageRequestHandler(orientation: .right)`), so Vision's returned boxes are in
  upright/portrait coordinates. But
  `AVCaptureVideoPreviewLayer.layerRectConverted(fromMetadataOutputRect:)` expects rects
  in the sensor's *native* (landscape) orientation and applies the preview connection's
  own `.portrait` rotation itself — so feeding it Vision's already-upright boxes rotated
  them a second time. That's what turned boxes narrow/tall and shifted them to the wrong
  part of the screen. (An earlier attempt set `videoOrientation = .portrait` on the
  `AVCaptureVideoDataOutput` connection and hinted Vision `.up` instead — that doesn't
  help, because `layerRectConverted` only knows about the *preview* connection's
  orientation, not the data output's, so Vision's boxes were still upright and still got
  double-rotated.) Fixed the way Apple's "Reading Phone Numbers in Real Time" sample does
  it: `CameraPreview` applies a fixed affine transform to each Vision box — flip
  bottom-left→top-left origin, then undo the portrait rotation — to bring it back into
  native sensor space *before* handing it to `layerRectConverted`, which then only has
  scale/crop/rotation to do once. The scanner is portrait-only (the preview connection is
  pinned to `.portrait`), and this transform assumes that.

Also: [ScannerView.swift](AllergyScanner/ScannerView.swift) previously had its whole view
(including the top bar/dismiss button) set to ignore the safe area — meant only for the
camera feed underneath — so the top bar rendered under the notch/Dynamic Island. Fixed by
scoping `.ignoresSafeArea()` to just the `CameraPreview` and removing it from the outer
wrapper in [HomeView.swift](AllergyScanner/HomeView.swift); the match-badges row's
hardcoded `padding(.top, 64)` (a guessed offset that only worked because the view used to
ignore the safe area entirely) was replaced with normal top-to-bottom `VStack` flow.

The Vision request was also switched from `.fast` to `.accurate` recognition (with the
camera pipeline processing every 3rd frame to keep it responsive) since ingredient print
is small and easy to misread at the faster setting.

**Scanner layout** — the dismiss button is now top-right (the standard placement most
apps use) rather than top-left, and the "results may be incomplete" reminder now sits at
the bottom of the screen instead of the top, out of the way of the camera view and the
match badges.

## Design

The app is intentionally two screens: **LabelLens** (add/remove the keywords to
watch for) and the full-screen **Scanner** (camera + live matches). The disclaimer is a
modal, not a third screen. Shared look-and-feel lives in
[Theme.swift](AllergyScanner/Theme.swift) — a brand accent color (set in
`AccentColor.colorset`), a reserved warning-red used only for actual keyword matches,
and a `cardBackground` view modifier used for the input field and keyword rows so both
screens read as one system rather than default-SwiftUI list/button styling.

## Project structure

```
AllergyScanner/
  AllergyScannerApp.swift    — app entry point, initializes the Google Mobile Ads SDK
  Theme.swift                 — shared colors, gradient, card style
  HomeView.swift              — keyword list UI, ad banner, Remove Ads / Restore Purchases
  HomeViewModel.swift         — keyword list persistence (UserDefaults)
  ScannerView.swift           — camera scanner UI (boxes + match labels)
  CameraPreview.swift         — UIViewRepresentable wrapping AVCaptureVideoPreviewLayer
  TextScannerService.swift    — camera capture + Vision OCR + match pipeline
  AllergenMatcher.swift       — keyword alias dictionary + phrase matching
  DisclaimerView.swift        — disclaimer screen
  AdBannerView.swift          — SwiftUI wrapper around a Google Mobile Ads banner
  InterstitialAdManager.swift — throttled full-screen ad shown when closing the scanner
  PurchaseManager.swift       — StoreKit 2 manager for the "Remove Ads" purchase
  Configuration.storekit      — local StoreKit test config (see below)
  Info.plist                  — camera usage description, AdMob app ID, SKAdNetwork ID
  Assets.xcassets/AppIcon     — 1024px light / dark / tinted icon PNGs (generated, see below)
Design/
  AppIconGenerator.swift      — CoreGraphics script that renders the three icon PNGs
```

**App icon** — a large magnifying glass on a blue gradient, with label lines inside the
glass and the matched word shown in red (the scanner's red box, in icon form). It's drawn
in code by
[Design/AppIconGenerator.swift](Design/AppIconGenerator.swift) rather than in a design
tool, so colors/layout can be tweaked and all three iOS 18 appearance variants (light,
dark, tinted) regenerated in one go:

```bash
swiftc -O Design/AppIconGenerator.swift -o /tmp/icongen && /tmp/icongen AllergyScanner/Assets.xcassets/AppIcon.appiconset
```

The Xcode project itself (target name, scheme) is still called `AllergyScanner` — the
in-app copy and display name are "LabelLens" and the bundle identifier is
`com.dina.ingredientfinder`. Rename the project too before shipping if you want full
consistency (bigger, separate step; it doesn't affect the App Store listing).

## Ads & in-app purchase

- **Ad network**: Google Mobile Ads SDK (AdMob), added via Swift Package Manager
  (`https://github.com/googleads/swift-package-manager-google-mobile-ads`, pinned to
  `13.x`). Two placements:
  - An adaptive **banner** at the bottom of the home screen.
  - An **interstitial** (full-screen, user-dismissable) that can appear when the user
    *closes* the scanner ([InterstitialAdManager.swift](AllergyScanner/InterstitialAdManager.swift)),
    wired up via the scanner `fullScreenCover`'s `onDismiss` in
    [HomeView.swift](AllergyScanner/HomeView.swift). It's deliberately never shown on the
    way *into* the scanner or during scanning — that's the moment the user actually needs
    the app (standing in an aisle holding a label), and interrupting it is both hostile
    and against AdMob's interstitial policy. Frequency is capped by three constants in the
    manager: the first `freeScansPerLaunch` (2) scanner closes after launch never show one,
    then at most one per `scansBetweenAds` (3) closes, and never more often than
    `minimumInterval` (3 minutes). Ads are preloaded in the background so they appear
    instantly; a failed load (no fill, no network) just means no ad that time. The whole
    thing is a no-op once Remove Ads is purchased.
- **Remove Ads**: a non-consumable In-App Purchase via StoreKit 2
  ([PurchaseManager.swift](AllergyScanner/PurchaseManager.swift)). Buying it hides the
  banner permanently; "Restore Purchases" re-applies it on a reinstall/new device. The
  price itself is never hardcoded in the app — `PurchaseManager` just displays whatever
  `product.displayPrice` the App Store returns, so setting the real price is done once,
  in App Store Connect, when you create the IAP (see below). Target price: €2.90.
- **Test IDs currently wired in** — these work out of the box but are Google's public
  sample IDs, not yours:
  - `GADApplicationIdentifier` in [Info.plist](AllergyScanner/Info.plist):
    `ca-app-pub-3940256099942544~1458002511`
  - Banner ad unit ID in [AdBannerView.swift](AllergyScanner/AdBannerView.swift):
    `ca-app-pub-3940256099942544/2435281174`
  - Interstitial ad unit ID in
    [InterstitialAdManager.swift](AllergyScanner/InterstitialAdManager.swift):
    `ca-app-pub-3940256099942544/4411468910`
  - **Before release**, replace all three with your real AdMob app ID plus a banner unit
    and an interstitial unit from an AdMob account, and create a matching **non-consumable** IAP in App Store Connect
    with product ID exactly `com.dina.ingredientfinder.removeads` (or change
    `PurchaseManager.removeAdsProductID` to whatever you use).
- **SKAdNetwork**: [Info.plist](AllergyScanner/Info.plist) currently declares only
  Google's own `cstr6suwn9.skadnetwork` identifier, which is enough for ads to serve. The
  SDK logs a warning that ~49 more identifiers are missing — those are for *install
  attribution* across AdMob's mediated ad networks, not required for ads to display. Add
  [Google's full recommended list](https://developers.google.com/admob/ios/query-ad-network)
  if you want fuller attribution reporting later.
- **Testing purchases locally**: [Configuration.storekit](AllergyScanner/Configuration.storekit)
  defines the Remove Ads product locally (priced at €2.90, German/Eurozone storefront, to
  match the intended real price) and is already wired into the shared Xcode scheme (`Run`
  action), so **Remove Ads** / **Restore Purchases** work in the simulator
  with no App Store Connect account or sandbox tester needed — as long as you launch via
  Xcode's Run button. Launching the built `.app` directly (e.g. via `simctl launch`)
  bypasses Xcode's StoreKit test session, so the purchase will correctly fail with a
  "product isn't available" error in that case — that's expected, not a bug.
- **Ads in the iOS Simulator**: the simulator can fail to load real ad network requests
  over HTTP/3 (QUIC) — a known Simulator networking quirk (visible in device logs as
  `nw_connection_copy_connected_local_endpoint_block_invoke` / "Network is down" errors
  on `googleads.g.doubleclick.net`), not an app bug. Ads load fine on a real device.
- **Not yet implemented**: App Tracking Transparency (ATT) / personalized ads, and a
  GDPR consent flow (Google's User Messaging Platform, which came along as a transitive
  dependency of the Ads SDK but isn't wired up). Only non-personalized/contextual ads are
  served right now, which is simpler and doesn't need either.

## Legal / liability

**This is not legal advice** — it's a description of the technical safeguards currently
in the app, added because scanning is inherently unreliable (OCR errors, an incomplete
keyword dictionary, labels it's never seen). If you plan to distribute this app publicly
(e.g. on the App Store), talk to an actual lawyer about a proper Terms of Use / liability
waiver — an in-app disclaimer helps show informed consent but isn't a substitute for one,
especially for an app whose failure mode could affect someone's health (even though the
app itself is deliberately framed as a general keyword finder, not an allergy tool).

What's implemented:

- **[DisclaimerView.swift](AllergyScanner/DisclaimerView.swift)** — a full-screen notice,
  shown before the app can be used at all, that the user must explicitly tap "I
  Understand & Agree" to dismiss (it can't be swiped away). It states plainly what the
  app does and doesn't do, lists concretely why scans can fail (OCR misreads, limited
  dictionary, no detection of ingredient substitutions), and that a missed/incorrect
  match doesn't mean a word isn't present.
- **Versioned re-acceptance** — [HomeView.swift](AllergyScanner/HomeView.swift) tracks
  acceptance via `acceptedDisclaimerVersion` in `UserDefaults`, compared against
  `currentDisclaimerVersion`. Bump that constant if you materially change the disclaimer
  wording later, to force existing users to re-accept.
- **Always-reachable copy** — a "Disclaimer & Limitations" link on the home screen reopens
  the same text (read-only) at any time.
- **On-screen reminder while scanning** — [ScannerView.swift](AllergyScanner/ScannerView.swift)
  shows a small persistent banner ("Results may be incomplete — double-check labels
  yourself") during the moment someone is most likely to over-trust a scan result.

Other things worth doing before a public release, that are outside what code alone can
fix: an App Store–listed privacy policy (Apple requires a URL for this regardless of
whether you collect data). Note this is no longer a "no network calls" app now that the
Google Mobile Ads SDK is integrated — it does make network requests (to serve ads and,
if you enable it later, for StoreKit/App Store communication), so the privacy policy
needs to disclose that and whatever AdMob's own data collection covers, rather than
claiming a pure on-device/no-network story. App Store description copy should also lead
with what the app actually does (find keywords on labels) rather than imply any
medical/health claim.

## Production setup: AdMob + App Store Connect + this app

Everything below is one-time account setup. Nothing in the code needs to change beyond
swapping the three placeholder IDs — the app already reads the product price from the
App Store and the ad units from the constants noted below.

### 1. Apple Developer / App Store Connect

1. **Enroll in the Apple Developer Program** (developer.apple.com, $99/year) with the
   Apple ID whose team is already selected in Xcode (`DEVELOPMENT_TEAM` in the project).
2. **Agreements, Tax, and Banking** (App Store Connect → Business): accept the
   **Paid Applications Agreement** and fill in bank + tax info. Until this is active,
   `Product.products(for:)` returns nothing, so the Remove Ads button will show without a
   price and purchases fail — this is the #1 cause of "my IAP doesn't load".
3. **Create the app record** (App Store Connect → My Apps → +): platform iOS, bundle ID
   `com.dina.ingredientfinder` (register it under Certificates, Identifiers &
   Profiles first, or let Xcode do it via automatic signing), SKU can be anything unique.
4. **Create the In-App Purchase** (the app record → Monetization → In-App Purchases → +):
   - Type: **Non-Consumable**
   - Product ID: exactly `com.dina.ingredientfinder.removeads` (must match
     `PurchaseManager.removeAdsProductID`)
   - Reference name, a display name + description for at least one localization, and a
     price (pick the nearest available price point to €2.90 — Apple's price points are
     fixed tiers, so it may end up as €2.99).
   - Upload a review screenshot (any screenshot of the home screen with the Remove Ads
     button is fine — it's only for App Review).
   - Its status must be **Ready to Submit**, and on the *first* submission it has to be
     explicitly attached to the app version (App Store version page → In-App Purchases
     and Subscriptions section) or it won't be reviewed/approved with the app.
5. **Sandbox tester** (Users and Access → Sandbox → Testers): create one with an email
   you don't use for a real Apple ID. On your test iPhone, Settings → App Store → Sandbox
   Account, sign in with it. Then in Xcode, edit the scheme → Run → Options → **StoreKit
   Configuration: None** to stop using the local `Configuration.storekit` and hit the real
   sandbox. (Switch it back for day-to-day development.)
6. **App Privacy** (app record → App Privacy): you *do* collect data now because of the
   Ads SDK. Declare what Google lists for the Mobile Ads SDK (device identifiers, usage
   data, diagnostics, coarse location if enabled, etc. — see Google's "App Store data
   disclosure" page for the SDK) and provide a **privacy policy URL** (required; it must
   mention AdMob / third-party advertising and, if you enable ATT, tracking).
7. **Export compliance**: add `ITSAppUsesNonExemptEncryption = NO` to `Info.plist` so
   every TestFlight/App Store upload doesn't stop to ask about encryption (the app only
   uses standard HTTPS).

### 2. AdMob

1. **Create an AdMob account** (admob.google.com) with a Google account. Fill in
   **Payments** (address, tax info, identity verification) — you can create ad units
   before this is done, but Google won't pay out (threshold: $100) and may restrict
   serving until it's complete.
2. **Add the app** (Apps → Add app → iOS). If the app isn't on the App Store yet, choose
   "No, it's not listed" and give it the name; you get an **App ID** of the form
   `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`. Once the app is live, go back and **link
   the App Store listing** (Apps → the app → App settings → App store link) — AdMob needs
   to verify the store listing, and unverified apps get limited ad serving after a grace
   period.
3. **Create two ad units** under the app (Ad units → Add ad unit):
   - **Banner** → note its unit ID `ca-app-pub-XXXX/BBBBBBBBBB`
   - **Interstitial** → note its unit ID `ca-app-pub-XXXX/IIIIIIIIII`
4. **Swap the three IDs in code** (all three are currently Google's public sample IDs):
   - `GADApplicationIdentifier` in [Info.plist](AllergyScanner/Info.plist) → the App ID
   - `adUnitID` in [AdBannerView.swift](AllergyScanner/AdBannerView.swift) → banner unit
   - `adUnitID` in [InterstitialAdManager.swift](AllergyScanner/InterstitialAdManager.swift)
     → interstitial unit
5. **Register your own phone as a test device** *before* running with real unit IDs
   (AdMob → Settings → Test devices → Add, using the IDFA the SDK prints to the Xcode
   console on first run, or set `MobileAds.shared.requestConfiguration.testDeviceIdentifiers`
   in Debug builds). Tapping your own real ads is treated as invalid traffic and gets
   AdMob accounts suspended — test devices always get marked test ads instead.
6. **app-ads.txt**: AdMob → Apps → the app → app-ads.txt shows a snippet. Host it at
   `https://<your-developer-website>/app-ads.txt`, where that website is the **Marketing
   URL / developer website** on the App Store listing. Optional, but without it some ad
   demand (and revenue) is withheld.
7. **SKAdNetwork IDs**: [Info.plist](AllergyScanner/Info.plist) declares only Google's
   own identifier. Paste in Google's full recommended `SKAdNetworkItems` list
   (developers.google.com/admob/ios/quick-start → "Update your Info.plist") so
   attribution works across Google's mediated networks.
8. **EU consent (GDPR) — required, not optional.** Google requires a certified consent
   management platform for users in the EEA/UK/Switzerland before ads can be served to
   them. AdMob → Privacy & messaging → create a **GDPR message** (and optionally the
   IDFA/ATT message). Then integrate the **User Messaging Platform** SDK in the app —
   it's already pulled in as part of the Swift package, but the code to request/present
   consent on launch is **not written yet** (see the checklist). Without it, EU users will
   simply get no ads (and, since the storefront/pricing is EU-centric, that's most of the
   audience).
9. **App Tracking Transparency (optional)**: if you want personalized (higher-paying)
   ads, add `NSUserTrackingUsageDescription` to `Info.plist` and prompt via
   `ATTrackingManager.requestTrackingAuthorization` before the first ad load. Skipping
   it is fine — you just get non-personalized ads and a simpler privacy label.

### 3. How the pieces connect

```
 Xcode target  ── bundle ID ──▶  App Store Connect app record  ──▶  IAP product
 (Info.plist:                    (Paid Apps agreement +              (product ID must equal
  GADApplicationIdentifier,       privacy policy URL)                 PurchaseManager.removeAdsProductID)
  SKAdNetworkItems)
        │
        └── App ID ─────────────▶  AdMob app  ──▶  banner unit ID       ──▶ AdBannerView.adUnitID
                                    (linked to      interstitial unit ID ──▶ InterstitialAdManager.adUnitID
                                     the App Store   GDPR message        ──▶ UMP consent flow (TODO)
                                     listing)        app-ads.txt         ──▶ hosted on marketing URL
```

Apple and Google never talk to each other directly. The only links are (a) the App Store
listing URL you paste into AdMob so it can verify the app, and (b) the developer website
that appears on the App Store listing and hosts `app-ads.txt`.

## Go-live checklist

Code / project:

- [ ] Replace `GADApplicationIdentifier` in `Info.plist` with your real AdMob App ID
- [ ] Replace `adUnitID` in `AdBannerView.swift` with your real banner unit ID
- [ ] Replace `adUnitID` in `InterstitialAdManager.swift` with your real interstitial unit ID
- [ ] Paste Google's full `SKAdNetworkItems` list into `Info.plist`
- [ ] Implement the UMP (GDPR) consent flow on launch — required for EU ad serving
- [ ] (Optional) Add ATT prompt + `NSUserTrackingUsageDescription` for personalized ads
- [ ] Add `ITSAppUsesNonExemptEncryption = NO` to `Info.plist`
- [ ] Set `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in the target (currently 1.0 / 1)
- [ ] Bundle ID is `com.dina.ingredientfinder` — **confirm you're happy with it before the
      first App Store submission**, because it can never change afterwards (the internal
      project/target name `AllergyScanner` is cosmetic and can be renamed any time)
- [ ] Bump `currentDisclaimerVersion` in `HomeView.swift` if the disclaimer text changed
- [ ] Register your test phone as an AdMob test device before running with real unit IDs
- [ ] Verify on a real device: scanner boxes land on the right words, banner loads,
      interstitial appears on the 5th scanner close, Remove Ads hides both (banner +
      interstitial), Restore Purchases works after reinstall

Apple accounts / listing:

- [ ] Apple Developer Program enrolled
- [ ] Paid Applications Agreement accepted; bank + tax info complete
- [ ] App record created with the right bundle ID
- [ ] Non-consumable IAP `com.dina.ingredientfinder.removeads` created, Ready to Submit,
      and attached to the first app version
- [ ] Purchase tested against the real sandbox (scheme StoreKit config = None, sandbox
      tester signed in on the device)
- [ ] Privacy policy published at a public URL and linked in the app record (mentions
      AdMob / third-party ads, and tracking if ATT is enabled)
- [ ] App Privacy questionnaire filled in per Google's Mobile Ads SDK disclosure
- [ ] Screenshots, description (lead with "find keywords on labels", no health/medical
      claims), keywords, support URL, marketing URL, age rating
- [ ] Reviewed the disclaimer with a lawyer (see **Legal / liability**)
- [ ] TestFlight build installed and run through on a real device before submitting

AdMob:

- [ ] AdMob account created; payments profile + tax + identity verification complete
- [ ] App added; banner + interstitial ad units created
- [ ] GDPR message created under Privacy & messaging
- [ ] `app-ads.txt` hosted on the marketing-URL website
- [ ] After the app is live: link the App Store listing to the AdMob app (verify it)

## Requirements

- Xcode (SwiftUI, iOS target)
- A device with a camera for testing the scanner (the simulator has no camera feed)

## Notes on current behavior

- The app is locked to portrait (`INFOPLIST_KEY_UISupportedInterfaceOrientations_*` in
  the Xcode target settings). The scanner's preview connection and the Vision→preview box
  mapping both assume portrait, so this keeps them consistent instead of showing a
  sideways feed in landscape.
- Once a keyword is flagged during a scan session, it stays in the on-screen alert list
  even if the camera moves away from that word — this is intentional (it's a running list
  of everything found while checking a given label), not a bug. The list resets each time
  the scanner is reopened (`TextScannerService.start()`).
- Pluralization handles regular `-s`/`-es`/`-ies` endings plus a handful of irregular
  food-relevant plurals (leaves/loaves/knives/etc.); it isn't a full stemmer, but keyword
  names rarely need one.

## Ideas for further improvement

- Let users select from a curated keyword list (with the aliases already built in)
  instead of only free text, to reduce typos.
- Expand the alias dictionary (it currently covers the common US/EU labeled allergens:
  milk, egg, peanut, tree nuts, wheat, soy, fish, shellfish, sesame, mustard, celery,
  lupin, sulphites — still useful as a general ingredient-derivative dictionary even
  without allergy framing).
- Real AdMob account + ad unit IDs, and the matching App Store Connect IAP product (see
  **Production setup** and the **Go-live checklist**).
- A one-time "Tired of ads? Remove them for €2.90" prompt after an interstitial closes,
  to capture the purchase intent the ad just created (the Remove Ads button on the home
  screen is the only path today).
