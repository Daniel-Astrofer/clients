# Cell operations in Admin

The Dashboard ReleaseCard retains Core runtime information and adds a Cell
operations panel. All reads and plan requests go through the authenticated Core
API `/api/admin/operations/cell`; the browser has no Bank credentials, database
access, shell deploy or restore action.

The panel displays current/target release IDs, sequences and complete selectable
digests, exact package/configuration bindings, signed report freshness, accepted
observer votes, blockers, backup/restore evidence, KFE maintenance mode/change/
revision/blocker counts, update phase/history and recorded plans. Bank evidence
is labeled VERIFIED only after Core verifies its pinned signature. Missing,
unavailable, malformed or stale evidence blocks readiness, even if an older API
incorrectly reports `ready:true`. The existing runtime signature is displayed
separately from optional runtime authorization.
Report expiry is checked locally as well as the snapshot/issuance age, so cached
evidence cannot outlive its signed expiry. Core sends `Cache-Control:no-store`.

`Create plan (no execution)` confirms the target then asks Core to recheck and
record intent. It can produce PLANNED or BLOCKED; the UI says deployment was not
executed. Planning needs verified, fresh target/package/configuration identities
and configured Core plan storage. Local artifact verification remains jctl's
offline package flow. Execution history comes from Bank; plan history is separate.
Snapshot freshness refreshes every 30 seconds while the panel is mounted; manual
refresh and dashboard pull-to-refresh refresh both snapshot and plan history.

Architecture: `AdminDataService` handles Core requests, Riverpod owns snapshot and
update providers, `CellOperationsView` checks missing evidence for presentation,
and `CellOperationsCard` renders evidence and records plan intent. Existing
mobile/desktop/web routing is preserved; this panel uses Flutter widgets without
platform-specific shell APIs.

Accessibility: all actions have visible labels; refresh has a tooltip; evidence
rows include semantic labels and selectable complete identifiers. Verification
and blockers use text in addition to color. Plan result announcements use a live
region. Rows wrap at narrow widths and the dashboard remains scrollable. Keyboard
focus and button disable behavior use standard Flutter controls. Tests exercise
missing evidence, stale readiness and a narrow 430px layout.

Backend details are owned by Core's `docs/reference/CELL_OPERATIONS_API.md`; Deploy
owns init/status/preflight and its exact `--deployment-manifest` validation.
Core consumes Contracts' normative signed Node observations with separate Bank
signatures. Those observations do not supply current deployment, restore or
execution history; missing fields remain explicit blockers, never fabricated
success. The Core Bank compatibility producer is still pending integration.

The inherited isolated baseline omitted the imported ApiTransport interface and
an asset directory referenced by pubspec. This change restores that interface
from ApiClient's existing get/post signatures and tracks the empty Lottie mount
so the affected application compiles without copying primary dirty changes.
