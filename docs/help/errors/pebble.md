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
3. If an installed game repeatedly fails verification, choose **Repair** in the launcher and confirm the additional download.

> [!IMPORTANT]
> Repair checks every installed file and may download a substantial amount of data. It does not reset launcher settings or the Wine prefix.

## Report this problem

A report only needs the code, operation, region, and whether Retry or Repair failed.

Contact the selected publisher's official support when the same payload is also unavailable through the selected region's official client; use the [publisher support routing table](../README.md#publisher-support-routing) for the correct contact.
