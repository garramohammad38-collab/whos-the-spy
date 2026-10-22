# مين الجاسوس؟ (Who's the Spy?)

Pass-and-play imposter party game for iPhone (SwiftUI, iOS 16+, portrait).

- `data/*.tsv` → `tools/build_cards.py` → `SpyGame/Resources/cards.json`
- `tools/strings_source.py` → `tools/build_strings.py` → `ar.lproj` / `en.lproj`
- `tools/make_assets.py` → icon, launch logo, sounds (all generated, original)
- `xcodegen generate` → `SpyGame.xcodeproj`
- CI: `codemagic.yaml` (`ios-all` = tests + screenshots + TestFlight build). Never submits for review.

Free decks: Today's Stars, Animals. Everything else: weekly/monthly subscription (see `AppStore/metadata.md`).
