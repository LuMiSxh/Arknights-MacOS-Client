---
title: PEBBLE
description: A game file could not be downloaded or verified
order: 20
audience: users
code: PEBBLE
domain: installation
---

# PEBBLE

A game file did not match the manifest size or checksum, or the transfer failed after the launcher retries.

## Try this

1. Choose **Retry**. The launcher reuses valid files and resumable `.part` downloads.
2. Check that the connection is stable and no proxy rewrites downloads.
3. If an installed game repeatedly fails verification, choose **Repair** and confirm the additional download.

> [!IMPORTANT]
> Repair checks every installed file and can download much data. It does not reset launcher settings or the Wine prefix.

## Report this problem

Report the code, operation, region, and whether Retry or Repair failed.

If the official client also cannot get the file, see [publisher support routing](../README.md#publisher-support-routing).
