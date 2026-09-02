---
title: GABBRO
description: The launcher rejected an unsafe or internally conflicting manifest
order: 30
audience: users
code: GABBRO
domain: installation
---

# GABBRO

The published manifest contains a path that escapes the selected install directory, appears more than once, or conflicts with another entry. The launcher stopped before writing that path.

## Try this

1. Choose **Retry** once in case the publisher replaced a temporary manifest.
2. Check whether the official client is currently updating or under maintenance.
3. If the code returns, choose **Report Problem**.

> [!CAUTION]
> Do not bypass this check or recreate the rejected path manually. Repair uses the same manifest and cannot make an unsafe manifest valid.

## Report this problem

Include the code, operation, and region.

This is usually a launcher/manifest compatibility problem. Contact the publisher's official support only if its official client rejects the same release.
