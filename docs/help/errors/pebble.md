---
title: PEBBLE
description: A game payload could not be downloaded or verified
order: 20
audience: users
code: PEBBLE
domain: installation
---

# PEBBLE

A downloaded game file did not match the size or checksum published in the manifest, or its transfer failed after the launcher's bounded retries.

## Try this

1. Choose **Retry** to reuse valid files and resumable `.part` downloads.
2. Check that the connection is stable and that no proxy or filter rewrites downloads.
3. If an installed game repeatedly fails verification, choose **Repair** and confirm the additional download.

> [!IMPORTANT]
> Repair checks every installed file and may download a substantial amount of data. It does not reset launcher settings or the Wine prefix.

## Logs and reports

`launcher.log` records the affected manifest entry and the detailed integrity result. Review paths and URLs before sharing excerpts. A report only needs the code, operation, region, and whether Retry or Repair failed.

Contact [Yostar Support](https://account.yo-star.com/contact) when the same official payload is unavailable in Yostar's own launcher.
