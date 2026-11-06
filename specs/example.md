---
title: Example Spec
parent: Specifications
nav_order: 1
permalink: /specs/example/
---

# Example Spec

**Status:** Draft · **Version:** 0.1

## Overview

Spec text goes here.

## Flow

```mermaid
sequenceDiagram
    participant Author
    participant Reviewer
    participant Log
    Author->>Log: Append revision
    Reviewer->>Log: Read revision
    Reviewer->>Log: Append signed review
    Log-->>Author: Review recorded
```
