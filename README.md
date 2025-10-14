# GitHub Container Registry CI/CD

A sample project demonstrating continuous integration and deployment using GitHub Container Registry (GHCR).

## Features

- Automated Docker image building
- Push to GitHub Container Registry
- GitHub Actions workflow integration

## Prerequisites

- Docker installed locally
- GitHub account with access to GHCR
- Repository secrets configured (if needed)

## Local Development

Build the Docker image locally:
```bash
docker build -t ghcr_ci_cd .
```

Run the container:
```bash
docker run -p 3000:3000 ghcr_ci_cd
```

## CI/CD Pipeline

This repository uses GitHub Actions to automatically:
1. Build Docker images on push to main branch
2. Tag images appropriately
3. Push to GitHub Container Registry

## License

MIT
