# Privacy Link Integration Concept

## Objective
Ensure users can access privacy details from all key entry points.

## Recommended placements

1. Landing page footer
- Link label:
  - DE: `Datenschutz`
  - EN: `Privacy`
- URL: `/privacy.html`

2. App settings screen
- Section: below "Project keys" panel
- Copy:
  - DE: `Datenschutz lesen`
  - EN: `Read privacy policy`
- Opens `/privacy.html` in new tab or in-app browser.

3. Auth screen (optional enhancement)
- Small helper line under login:
  - `Privacy`
- Useful before first login for trust.

4. Future native wrappers
- iOS/Android legal links in store listing should point to:
  - Privacy policy: `/privacy.html`
  - Terms: `/docs/terms-of-service.md` (or future `/terms.html`)

## Tracking recommendation
- No analytics required.
- If needed later, only aggregate click count, no user identifiers.
