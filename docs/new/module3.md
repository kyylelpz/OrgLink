# Module 3: Events and Registration

Source-reviewed 30 October 2026. Reuses lifecycle, registration and image-recovery explanations from [the existing guide](../module3.md), correcting obsolete poster-layout and identity-write descriptions.

## Event Lifecycle and Authority

Assigned managers create/manage organization events. An active officer with `manageEvents` creates and edits/submits their own events; it does not grant review/publication or attendance authority. Platform Admin has no implicit event power. Active organization/account requirements apply independently.

| Transition | Required authority/state |
| --- | --- |
| Create | Manager or permitted officer; draft/pending, unsubmitted, zero registrations, no poster reference |
| Edit | Manager or creator officer; editable unarchived draft; clears approval to pending/unsubmitted |
| Submit | Editable draft; validates future schedule/deadline and locks while review pending |
| Approve/Reject | Assigned manager; submitted pending draft; manager may approve their own event |
| Publish | Manager; approved valid draft; publication is separate from approval |
| Cancel | Manager; draft or published, unarchived |
| Complete | Manager; published, event end reached |
| Archive | Manager; completed or cancelled; writes archivedAt rather than changing eventStatus |

Fields include title, description, venue, start/end/deadline timestamps, capacity, visibility and poster reference. Validation requires nonblank bounded strings, future start, end after start, future deadline no later than start and integer capacity 1–100000. Private organizations require private events. Server Rules enforce transitions regardless of UI state or device time.

Discovery provides text/organization/time filtering and sorting. My Events derives own registration history, including withdrawn/cancelled records and current event availability. Managers see management lists; officers' editing queries are creator-scoped. Authorized attendance operators may read event context needed for verification. Drafts are not ordinary published discovery content.

## Posters

Current Create/Edit screens use separate Event Poster and Event Details cards. Create stages optional image bytes locally, creates the draft, then uploads/finalizes against that event ID. Failed upload leaves the saved draft and selection available; Retry Upload targets that draft, with saved text locked to prevent duplicate creation. Leaving with a pending selection requires confirmation; forced account redirects remain possible. Image bytes do not survive process termination.

The shared cropper supports landscape drag/pinch, Reset, Confirm, Cancel and Keep Original. Profiles/logos retain square cropping. There is no displayed secondary Home preview. The crop instruction still mentions a trim shown below; this is a confirmed minor text defect. The selected local draft preview uses contain; published poster widgets use cover. Older same-card/secondary-preview explanations are obsolete.

Poster reference changes require an editable draft and the manager or creator officer's authority. Worker image finalization resets approval and verifies asset ownership/revision. Arbitrary client posterURL mutation is denied. See [architecture](architecture.md) for the upload protocol and cleanup.

## Registration and Withdrawal

Eligible users confirm registration before saving. A public event permits eligible participants without requiring membership; private event registration requires active organization membership. Manager assignment alone is not a private membership. Rules recheck active organization, published/approved state, deadline, start time, visibility and capacity.

Registration uses a transaction reading event, own record and own profile. It writes `registrations/{uid}`, a safe `participantIdentities/{uid}` name projection and the paired event counter. UID document identity prevents independent duplicates; capacity is checked against the original counter and paired delta by Rules. Re-registration changes the retained cancelled record rather than creating a second UID.

Withdrawal uses an atomic batch of own registration status → cancelled and event counter increment(-1), without requiring a private event read. Rules enforce the original registered state, positive counter and cutoff. This supports release of a reservation after visibility/membership loss. Cancellation of an event does not reopen registration; withdrawal is allowed only before the same deadline/start cutoff. Unknown network outcomes require reconciling the final server state before retrying.

The six registration fields retain the original registeredAt. Registration and re-registration supply the current name projection; withdrawal preserves it and does not require rewriting it. Names can be refreshed for an existing registration. Participant views expose names/status/timestamps, not private profiles, emails or Student Numbers. Missing historical projection is Unknown Participant. The projection persists with retained participation records.

## States, Tests and Limits

Screens include loading/timeouts, empty catalogs, inaccessible context, retry, field errors, confirmations and success/error feedback. Scopes follow identity/permissions; no cached count grants a registration. EventHub combines organization-scoped subscriptions rather than assuming unrestricted collection-group event queries.

Sources: `lib/features/events/`, `lib/features/organizations/data/services/organization_service.dart`, `firebase/firebase.rules`, `firebase/firestore.indexes.json`, Worker `images.js`. Tests: `test/{event_workflow,event_view_models,event_creation_poster,event_poster_crop,participants,phase5_6_ui}_test.dart`, `firebase/tests/{event,images}.rules.test.mjs`, Worker image unit/emulator tests.

Client transaction correctness plus tested Security Rules protects capacity; there is no separate event-registration Worker endpoint. Emulator tests do not verify deployed composite-index availability. Event/request state changes preserve review metadata but do not provide a comprehensive append-only event activity feed. Calendar, ratings, announcements and registration notifications remain gaps; see [compliance](requirements-compliance.md).
