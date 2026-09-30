# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project goal

A movie search app for kids, built to try out MongoDB's vector search features. Target MongoDB 8.3 (GA May 2026). Vector search has been available on self-managed Community Edition since 8.2, via the `mongot` search engine and the `$vectorSearch` aggregation stage. 8.3 adds automated embeddings and native hybrid search (`$rankFusion`, `$scoreFusion`).

Self-managed `mongot` runs on Linux only (no native macOS or Windows builds), so run MongoDB in Docker when developing on macOS.

## Instructions

- Write everything in English: code, comments, commit messages, documentation, and ADRs.
- Keep the design simple. Prefer the most straightforward solution that works; avoid premature abstractions, extra layers, and unnecessary dependencies.
- Update `README.md` every time a feature is added.
