# Nix Dev Environment

This repository provides a reusable Nix development container using Docker Compose.  
Your local `~/projects` directory is mounted inside the container at `/home/dev/projects`.

---

## Quick Start

1. **Start the container in the background (autostart)**

```bash
docker compose up -d
```

This will start the container in detached mode and pull the image automatically if needed.

2. **Connect to the container**

```bash
docker exec -it nix-dev-env bash
```

You are now inside the dev environment.

---

## Stop the Container

To stop the running container:

```bash
docker compose stop
```

To stop and remove the container completely:

```bash
docker compose down
```

---

## Notes

* Any changes in `~/projects` are automatically reflected inside `/home/dev/projects`.
* To update the image to the latest version:

```bash
docker compose pull
docker compose up -d
```


