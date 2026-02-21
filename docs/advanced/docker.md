# Docker & Containers

Pimarchy comes pre-configured with **Docker CE** and **Docker Compose v2**. This makes it easy to deploy services directly to your Pi.

## Installation Process

Pimarchy uses the official Docker repository from `download.docker.com`.
- **Not Debian's `docker.io`:** The Debian `docker.io` package is often outdated and doesn't include the official `docker-compose-plugin`.
- **Idempotent:** If Docker is already installed, the script will skip the installation but ensure the repositories and keys are correctly configured.

## Managing Containers

You can manage your Docker containers with standard commands:

```bash
# Check Docker version
docker --version

# Check Docker Compose version
docker compose version

# List running containers
docker ps
```

## Running as a User

Pimarchy automatically adds your user to the `docker` group. This allows you to run Docker commands without prefixing them with `sudo`.

!!! note "Group Update"
    If you find that you still need to use `sudo`, you can refresh your user group status:
    ```bash
    newgrp docker
    ```
    Or simply log out and back in.

## Common Use Cases

### Web Dashboard
Deploy a web dashboard for your Pi:
```bash
docker run -d --name dashy -p 8080:80 lissy93/dashy:latest
```

### Development Environments
Spin up a local development environment:
```bash
# Example Docker Compose file
version: "3.8"
services:
  db:
    image: mariadb:latest
    environment:
      MARIADB_ROOT_PASSWORD: password
    ports:
      - "3306:3306"
```

## Storage & Performance

- **NVMe Storage:** If you are running Docker on a Pi 5, we highly recommend an NVMe or High Speed USB SSD for the best performance.
- **MicroSD wear:** Frequent writes to a MicroSD card (common with Docker) can lead to premature card failure.
