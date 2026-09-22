# its-giving-cartoon

A portfolio project exploring Retrieval-Augmented Generation (RAG) built on top of **MongoDB Community Edition**.

## Overview

This project is a personal sandbox to learn and demonstrate how a full RAG pipeline can be built using only MongoDB Community Edition as the data and vector store — without relying on MongoDB Atlas or a managed vector search service. It covers the full stack, end to end:

- **Infra** — local/self-hosted environment (MongoDB Community Edition, app services, orchestration)
- **ETL** — ingestion pipeline that extracts, cleans, chunks and embeds source documents
- **RAG** — retrieval and generation logic built on top of MongoDB
- **API** — backend service exposing RAG capabilities
- **Front** — client application to query and visualize results

> Status: early stage. This repository currently contains only project scaffolding; architecture and implementation are in progress.

## Why MongoDB Community Edition?

Vector search is typically offered as a managed feature (e.g. MongoDB Atlas Search). This project intentionally uses the **Community Edition** instead, as a constraint-driven learning exercise:

- No managed Atlas Vector Search index is available.
- Embeddings and similarity search need to be implemented and evaluated manually (e.g. storing vectors as document fields and computing similarity via aggregation pipelines or application-level computation).
- The goal is to understand the trade-offs of running RAG on infrastructure you fully own and control.

## Architecture

```
┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐
│  Front  │ --> │   API   │ --> │   RAG   │ --> │   ETL   │ --> │  Infra  │
└─────────┘     └─────────┘     └─────────┘     └─────────┘     └─────────┘
                                     |                               |
                                     v                               v
                              MongoDB Community Edition (documents + embeddings)
```

### Infra

Local/self-hosted infrastructure needed to run the project: MongoDB Community Edition instance, containerized services, and orchestration (e.g. Docker Compose). Details to be defined as the project takes shape.

### ETL

Pipeline responsible for:
1. Extracting raw source content (documents to be defined, in line with the project's theme).
2. Cleaning and chunking text into retrievable units.
3. Generating embeddings for each chunk.
4. Loading chunks and embeddings into MongoDB collections.

### RAG

Core retrieval and generation logic:
- Similarity search over embeddings stored in MongoDB (custom implementation, since Community Edition has no native vector index).
- Context assembly from retrieved chunks.
- Generation step using a language model, augmented with the retrieved context.

### API

Backend service exposing the RAG pipeline (query endpoint, health checks, etc.). Language/framework to be defined.

### Front

Minimal client application to interact with the API: submit queries and display generated answers along with their retrieved sources.

## Repository structure (planned)

```
.
├── infra/    # infrastructure and environment setup
├── etl/      # ingestion and embedding pipeline
├── rag/      # retrieval and generation logic
├── api/      # backend API
└── front/    # client application
```

## Getting started

Not yet available — instructions will be added once the initial implementation lands.

## Roadmap

- [ ] Define infra setup (MongoDB Community Edition + orchestration)
- [ ] Define source dataset and ETL pipeline
- [ ] Implement embedding storage and similarity search in MongoDB
- [ ] Implement RAG query flow
- [ ] Expose RAG via an API
- [ ] Build a minimal front-end
