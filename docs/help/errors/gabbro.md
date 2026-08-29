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

1. Choose **Retry** once in case Yostar replaced a temporary manifest.
2. Check whether the official client is currently updating or under maintenance.
3. If the code returns, choose **Report Problem**.

> [!CAUTION]
> Do not bypass this check or recreate the rejected path manually. Repair uses the same manifest and cannot make an unsafe manifest valid.

## Logs and reports

Include the code, operation, and region. `launcher.log` contains the rejected entry for maintainers, but review it before posting because paths can reveal local folder names.

This is usually a launcher/manifest compatibility problem. Contact [Yostar Support](https://account.yo-star.com/contact) only if their official launcher rejects the same release.
