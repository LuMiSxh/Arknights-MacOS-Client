---
title: Optional privacy-preserving telemetry
description: Proposed privacy and infrastructure boundaries for optional anonymous telemetry
order: 20
hidden: true
---

# Optional privacy-preserving telemetry

Status: Proposed
Related issue: [#55 — Collect anonymous telemetry](https://github.com/LuMiSxh/Arknights-MacOS-Client/issues/55)

## Summary

Arknights Client may offer optional telemetry to learn which launcher features and compatibility
settings matter, which operations fail, and which languages would benefit users. Collection must be
explicitly enabled, remain independent from publisher services, and avoid identifiers or per-installation
profiles.

The initial design should favor occasional, one-shot campaigns over continuous event collection. A
Cloudflare Worker validates each submission and immediately converts it into coarse aggregate
counters. It must not retain complete responses, source IP addresses, request headers, or exact
timestamps.

Remote configuration may select only measurement probes compiled into the reviewed application.
It must never contain executable code, scripts, paths, arbitrary URLs, or commands.

## Goals

- Explain what is collected and why before any telemetry request is made.
- Make participation optional, disabled until the user makes an explicit choice, and reversible.
- Measure feature use, compatibility outcomes, approximate world region, and language demand without
  assigning a stable installation or device identifier.
- Keep collection asynchronous, best-effort, and outside installation, update, and launch critical
  paths.
- Operate within Cloudflare's free quotas at the project's expected scale.
- Manage infrastructure through Terraform and protected GitHub Actions workflows.
- Make spoofing and replay expensive enough that aggregate results remain useful without turning
  telemetry into an identity system.

## Non-goals

- Measuring individual users, retention, sessions, funnels, or daily active users.
- Correlating activity across campaigns or application reinstalls.
- Uploading logs, crashes, free text, screenshots, game data, or account information.
- Running remotely supplied Swift, JavaScript, WebAssembly, shell commands, plugins, or binaries.
- Treating telemetry as authoritative operational or billing data.
- Blocking any launcher or game feature when telemetry is disabled or unavailable.

## Consent and user experience

The launcher should present an Apple-style choice during onboarding or after an update that introduces
the feature. Neither option should be visually disadvantaged, and the affirmative option must not be
preselected.

Suggested English copy:

> **Help improve Arknights Client**
>
> If enabled, the launcher occasionally sends privacy-preserving counts about used features,
> compatibility settings, coarse success or failure categories, approximate world region, and
> preferred app language. It never sends account data, identifiers, paths, logs, or game content.
> Cloudflare processes the network request. You can change this choice at any time in Settings.

Suggested actions:

- **Share Usage Data**
- **Do Not Share**
- **See Exactly What Is Shared**

Settings must expose the same choice and a precise field list. Withdrawing consent stops future
collection, cancels telemetry tasks, and deletes any pending local payload. A request that the Worker
has already accepted may already have incremented an aggregate and cannot be rolled back. Those counts
cannot be attributed to an installation and therefore cannot be selectively deleted.

Consent should have a version. Adding a new data category outside the currently described scope must
increment that version and request consent again. A remote campaign cannot widen the consent scope.

## Threat model and privacy invariants

This design aims to resist generic endpoint spam, replay, accidental overcollection, compromised remote
campaign hosting, and routine inspection of stored telemetry. It does not defend against a malicious
reviewed application release, a maintainer with production-secret access, an attacker controlling the
user's Mac, or Cloudflare acting outside its contractual commitments.

The word _privacy-preserving_ describes the minimization and unlinkability controls in this proposal;
it is not a mathematical proof of anonymity. A reporting threshold reduces disclosure in published
results but does not transform personal data into anonymous data by itself.

The following invariants are release blockers:

- no request is made before explicit consent;
- no stable installation, device, account, or cross-campaign identifier exists;
- no raw submission or full response combination is persisted;
- no remote input expands the set of compiled probes or their local access;
- no telemetry failure affects normal launcher or game behavior;
- Cloudflare's normal processing of connection metadata is disclosed even though the project does not
  copy that metadata into its telemetry store.

## Data model

### Allowed categories

Values must be fixed enums or coarse buckets, for example:

- launcher and runtime version;
- Global, Japan, or Korea game region;
- macOS major version;
- broad Apple chip generation and tier;
- broad memory and resolution buckets;
- MSYNC or ESYNC, HiDPI, Game Mode, display mode, and other known launcher settings;
- install, refresh, and launch outcome enums;
- coarse duration, transfer, and frame-rate buckets;
- known failure classes without error messages;
- approximate continent derived by Cloudflare;
- preferred base language, such as `en`, `de`, `es`, `fr`, `ja`, or `ko`.

### Prohibited categories

The client and Worker must reject:

- stable installation IDs, device IDs, serial numbers, advertising IDs, and cross-campaign tokens;
- usernames, account identifiers, login data, payment data, and publisher credentials;
- home, installation, cache, Wine-prefix, or log paths;
- URLs, request or response bodies, process lists, and installed-application lists;
- logs, crash reports, exception messages, Wine output, Chromium output, and arbitrary text;
- screenshots, clipboard data, keyboard input, and document contents;
- exact hardware model strings, display dimensions, coordinates, or timestamps;
- complete combinations of otherwise coarse values when those combinations could fingerprint a Mac.

Existing issue-report metadata is not safe to reuse unchanged because it includes the raw CPU brand
string and physical-memory value. Log-upload behavior must preserve the existing rule that users
review and attach diagnostics themselves.

## Aggregation and unlinkability

The Worker should transform a submission into independent counters and discard the original payload.
A possible D1 shape is:

```text
campaign_id | metric             | bucket       | count
------------|--------------------|--------------|------
2026-09-01  | preferred_language | es           | 12
2026-09-01  | continent          | south_america| 8
2026-09-01  | sync_mode          | msync        | 41
```

The database should not contain a row representing one installation's complete response. Where a
product decision genuinely needs a relationship, the campaign may define a small, reviewed pair such
as `chip_bucket × fps_bucket`. Arbitrary joins across all submitted dimensions remain impossible.

Reports should suppress buckets with fewer than a chosen threshold, initially five responses. Counts
remain directional because the design deliberately cannot prove unique users or prevent a reinstall
from answering again.

### Proposed retention

| Data                        | Proposed retention                                                           |
| --------------------------- | ---------------------------------------------------------------------------- |
| Pending payload             | Memory only; discarded after the single attempt, app termination, or opt-out |
| Completed campaign IDs      | Bounded to the latest 100 IDs; cleared by launcher-settings reset            |
| Used challenge digests      | Expiry plus a short grace period, no longer than 15 minutes                  |
| Aggregate campaign counters | 12 months, then delete the complete campaign aggregate                       |
| Campaign manifests          | Repository history; manifests contain configuration but no user data         |

Cloudflare may separately process and retain ordinary service metadata under its own product settings
and terms. Disabling Worker invocation logs and application logging minimizes project-accessible logs
but does not mean Cloudflare never processes the source IP or request metadata.

## Approximate region and language

Cloudflare Workers expose an IP-derived continent in `request.cf.continent`. The Worker should map it
immediately to one of:

- Europe;
- North America;
- South America;
- Asia;
- Africa;
- Oceania;
- Other or unknown.

The client does not need location permission and should not send a country, city, region, postal code,
coordinates, timezone, or IP address. The Worker must not persist the source IP used to derive the
continent. Missing geolocation maps to `other`. VPNs, relays, travel, and geolocation errors make this
an approximate signal only.

Continent alone is not a reliable language signal. The client may separately submit the selected app
language. If the launcher follows the system language, it may normalize the first preferred macOS
language to its base code: `es-MX` becomes `es`. Unsupported or rare values become `other`; the full
locale is never submitted. The campaign defines the accepted base-language allowlist. A missing value
and a language outside that allowlist both map to `other`.

Continent and language should normally be aggregated independently. A reviewed `continent × language`
pair may be collected for a specific localization decision, subject to the same minimum reporting
threshold.

## Cloudflare architecture

The smallest proposed deployment is:

```text
Opted-in client
    |-- GET /v1/campaigns
    |-- GET /v1/challenge
    `-- POST /v1/submissions
                |
         Cloudflare Worker
         - method and content-type checks
         - body and field limits
         - campaign and enum validation
         - build proof and replay checks
         - rate limits and hard quotas
         - continent bucketing
                |
         D1 aggregate counters
```

D1 is preferable for the first implementation because it can retain only intentionally aggregated
counters and can use an EU location hint. Analytics Engine is an alternative for later continuous,
coarse event metrics, but it retains data points for three months and uses adaptive sampling.

Workers invocation logs, persistent traces, and request logging should be disabled for this service.
Code must never log the request object, IP address, user agent, payload, challenge, or build proof.

The service must fail closed for telemetry: invalid or over-quota submissions are discarded. A failure
must never affect normal application behavior.

## Official-build proof and abuse resistance

### What a build secret can and cannot do

GitHub Actions can inject a separate value into the official release build. Once that value ships in
the DMG, it is extractable from the executable, resources, process memory, or network behavior. It is
therefore an official-build token, not a durable secret or proof of an unmodified running process.

It may still reject unsophisticated generic spam and distinguish official release builds from ordinary
source builds. It must never be a Cloudflare API token, Terraform credential, Worker deployment token,
Turnstile secret, campaign-signing key, or credential accepted by any other service.

### Version-scoped build keys

A protected GitHub release environment and the Worker may share a `TELEMETRY_BUILD_MASTER`. The release
workflow derives a separate key from the bundle identifier, marketing version, and build number. Only
that derived key is embedded in the official application.

The proposed derivation is HKDF-SHA256 with a 32-byte master, a protocol-specific salt, and a
length-delimited `bundle identifier`, `marketing version`, and `build number` info value. Requests use
HMAC-SHA256. The MAC covers the SHA-256 digest of the exact UTF-8 request-body bytes, so client and
server do not depend on equivalent JSON reserialization.

Compromise of one release key must not reveal the master or keys for other versions. The Worker accepts
only explicitly supported versions and retires old keys after a documented window. Local development
builds contain no production key and leave telemetry disabled.

Secret values must not enter Terraform state, build logs, release notes, checksums, provenance metadata,
or committed generated sources. Cloudflare deployment credentials and the master remain server-side.

### Challenge-response

Before submission, the client obtains a random challenge containing a campaign ID and short expiry.
It authenticates the payload with the version-scoped key over:

```text
protocol_version || challenge || campaign_id || app_version || SHA256(exact_request_body)
```

Every variable-width component is length-delimited. The Worker verifies the proof and atomically
inserts a digest of the random challenge under a unique D1 key before incrementing counters. A duplicate
insert rejects a replay. The digest has no relationship to an installation and expires automatically
within 15 minutes. A captured submission cannot be replayed or modified, but an attacker who extracts
the release key can still create new valid submissions.

### Additional defenses

The service should combine the build proof with:

- strict schema, enum, count, and body-size limits;
- a short challenge lifetime;
- one accepted submission per challenge;
- Cloudflare WAF and Worker rate limits using IP only as an ephemeral abuse signal;
- a hard global daily submission cap below the free quota;
- per-campaign caps and anomaly detection;
- rejection or quarantine of statistically implausible bursts;
- no retries after ambiguous success for one-shot campaigns.

If extracted build keys become an observed problem, a campaign may require a small, benchmarked
proof-of-work bound to the challenge and payload. This raises the cost of bulk submissions without
introducing an identity, but it should not be enabled by default because telemetry must remain gentle
on battery and CPU.

Turnstile may protect an explicitly opened survey through a web view. It should not interrupt background
telemetry; suspicious background submissions are better discarded. Private Access Tokens optimize
browser challenges and are not general native API credentials.

Apple App Attest is not a baseline solution. Native macOS support starts with macOS 27, while this
project supports macOS 15 and later. The current application is also ad-hoc signed. A later Developer-ID
and macOS-27 path could use App Attest for high-risk campaign enrollment, but its per-installation key
must remain separated from telemetry records to avoid creating a pseudonymous activity profile.

## Remote campaigns

Campaign manifests may select only fixed probes implemented in the installed application. A canonical,
signed envelope should contain:

```json
{
  "protocolVersion": 1,
  "keyID": "campaigns-2026-01",
  "campaignID": "sync-mode-2026-09",
  "issuedAt": "2026-09-01T00:00:00Z",
  "expiresAt": "2026-09-30T00:00:00Z",
  "minimumClientVersion": "0.5.0",
  "maximumClientVersion": "0.5.99",
  "consentScopeVersion": 1,
  "probes": ["clientVersion", "region", "syncMode"],
  "signature": "base64url-ed25519-signature"
}
```

The signature is Ed25519 over the RFC 8785 canonical JSON object without the `signature` member. Version
bounds are inclusive semantic versions. The application embeds the public key identified by `keyID`.
The signing private key must not ship in the app or reside in Terraform state. Adding a new trusted key
requires a normal application release; old keys may be removed the same way.

Remote fields must not specify code, shell commands, regular expressions, file or process names,
filesystem paths, arbitrary network destinations, plugins, dynamic libraries, or probe parameters that
expand local access. Unknown fields, probes, consent versions, signatures, or protocol versions cause
the complete campaign to be rejected.

The client stores a bounded set of completed campaign IDs locally. Probe implementations are read-only,
idempotent, and free of externally visible side effects. Adding or changing a probe implementation is
reviewed and tested as ordinary application code in a normal release. A campaign runs only after
telemetry consent, within its validity window, and on a best-effort basis at most once per local
installation. Reinstalling may cause another submission; no server-side installation identifier is
introduced to prevent it.

## Infrastructure and delivery

Terraform should own the Worker, D1 database, bindings, routes, rate-limit configuration, and other
Cloudflare resources. The same Worker resource must not also be deployed independently with Wrangler,
because two deployment owners would create drift.

GitHub Actions should use:

- formatting, validation, and a Terraform plan on pull requests without production credentials;
- an environment-protected apply from the protected default branch or a manual dispatch;
- a remote state backend, never committed Terraform state;
- least-privilege Cloudflare tokens scoped to the relevant account and resources;
- pinned Terraform and action versions;
- workflow concurrency that prevents parallel production applies;
- separate staging and production datasets and secrets.

Infrastructure configuration may be declared in Terraform, but secret values should be injected by a
protected deployment step into Cloudflare Worker Secrets or Secrets Store rather than written into
Terraform inputs that persist in state. Terraform owns the Worker code, binding declarations, and
resource lifecycle; the protected secret step changes only the declared secret values and does not
deploy Worker code.

## Free-tier expectations

As of August 2026, the relevant documented free quotas are:

- Workers: 100,000 requests per day and 10 ms CPU per invocation;
- D1: 100,000 rows written and 5 million rows read per day, with 5 GB total storage;
- Analytics Engine, if later used: 100,000 data points and 10,000 read queries per day.

Current release download counts are orders of magnitude below these limits. The Worker should still
enforce a lower internal cap because Cloudflare budget notifications are not an immediate circuit
breaker and public endpoints can be attacked. Pricing and limits must be rechecked before implementation.

## Suggested rollout

1. Publish the privacy explanation and exact proposed field list for review.
2. Implement consent and local campaign state with a no-op transport.
3. Deploy a staging Worker and D1 aggregate schema with logs disabled.
4. Validate strict schemas, consent withdrawal, retries, quota failures, and replay rejection offline.
5. Run an explicit developer-only campaign against staging.
6. Enable a small production cohort through a signed declarative campaign.
7. Inspect only thresholded aggregates and audit that no raw payload or request metadata is retained.
8. Decide whether the signal justifies broader opt-in availability.

## Open decisions

- Whether the first version needs D1 correlations or only independent counters.
- The consent-scope version and exact initial field list.
- The minimum reporting threshold for small buckets.
- How long a release build key remains accepted.
- Whether the build-key master is shared with release CI or separate random release keys are registered
  during deployment.
- The internal daily cap and anomaly policy.
- Whether approximate continent and preferred base language belong in the initial consent scope.
- Whether a future continuous-event mode is valuable enough to justify Analytics Engine.

## References

- [Apple App Review Guidelines: privacy and consent](https://developer.apple.com/app-store/review/guidelines/)
- [Apple App Attest validation](https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server)
- [Apple WWDC26: App Attest on macOS 27](https://developer.apple.com/videos/play/wwdc2026/201/)
- [Cloudflare Workers limits](https://developers.cloudflare.com/workers/platform/limits/)
- [Cloudflare Workers request geolocation properties](https://developers.cloudflare.com/workers/runtime-apis/request/)
- [Cloudflare Workers rate limiting](https://developers.cloudflare.com/workers/runtime-apis/bindings/rate-limit/)
- [Cloudflare Worker Secrets](https://developers.cloudflare.com/workers/configuration/secrets/)
- [Cloudflare D1 pricing](https://developers.cloudflare.com/d1/platform/pricing/)
- [Cloudflare D1 data location](https://developers.cloudflare.com/d1/configuration/data-location/)
- [Cloudflare Analytics Engine pricing](https://developers.cloudflare.com/analytics/analytics-engine/pricing/)
- [Cloudflare Analytics Engine limits and retention](https://developers.cloudflare.com/analytics/analytics-engine/limits/)
- [Cloudflare Turnstile native-app web views](https://developers.cloudflare.com/turnstile/get-started/mobile-implementation/)
- [Cloudflare Turnstile server-side validation](https://developers.cloudflare.com/turnstile/get-started/server-side-validation/)
- [Cloudflare Terraform provider](https://developers.cloudflare.com/api/terraform/)
- [GDPR principles and consent](https://eur-lex.europa.eu/eli/reg/2016/679/)
- [Announcement behavior](../announcements.md)
- [Architecture](../architecture/README.md)
- [Storage](../../help/storage.md)
- [Troubleshooting and diagnostic handling](../../help/troubleshooting.md)
