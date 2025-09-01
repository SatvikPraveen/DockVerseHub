# Docker Terminology Reference & Glossary

**Location: `docs/glossary.md`**

## A

**Alpine Linux**  
A lightweight Linux distribution commonly used as a base image for Docker containers due to its small size (~5MB).

**API Gateway**  
A service that acts as an entry point for microservices, handling request routing, authentication, and rate limiting.

**Application Container**  
A container that runs a specific application or service, as opposed to a system container.

**Attach**  
Connect to a running container's input/output streams to interact with it.

**Automated Build**  
A Docker Hub feature that automatically builds images from a Git repository when code changes are pushed.

## B

**Base Image**  
The starting point for building a Docker image, specified in the FROM instruction of a Dockerfile.

**Bind Mount**  
A method of mounting a host directory or file into a container, providing direct access to host filesystem.

**Bridge Network**  
The default network driver that creates an internal network on a single host, allowing containers to communicate.

**Build Context**  
The set of files and directories sent to the Docker daemon when building an image.

**BuildKit**  
Docker's enhanced build engine that provides improved performance, caching, and advanced features like multi-stage builds.

## C

**cgroups (Control Groups)**  
Linux kernel feature used to limit and isolate resource usage (CPU, memory, disk I/O) for processes.

**Container**  
A lightweight, portable, and isolated environment that packages an application with its dependencies.

**Container Image**  
A read-only template used to create containers, containing the application code, runtime, system tools, and libraries.

**Container Registry**  
A repository for storing and distributing Docker images (e.g., Docker Hub, AWS ECR, Harbor).

**Copy-on-Write (CoW)**  
A storage mechanism where data is only copied when modified, improving efficiency in Docker's layered filesystem.

**containerd**  
An industry-standard container runtime that manages container lifecycle on Linux and Windows.

## D

**Daemon**  
The Docker daemon (dockerd) that manages Docker objects like images, containers, networks, and volumes.

**Docker Compose**  
A tool for defining and running multi-container applications using a YAML configuration file.

**Docker Hub**  
Docker's cloud-based registry service for sharing container images publicly or privately.

**Docker Swarm**  
Docker's native clustering and orchestration tool for managing multiple Docker hosts as a single cluster.

**Dockerfile**  
A text file containing instructions to build a Docker image automatically.

**Distroless Images**  
Container images that contain only the application and runtime dependencies, without a package manager or shell.

## E

**Entrypoint**  
The command that runs when a container starts, defined by the ENTRYPOINT instruction in a Dockerfile.

**Environment Variables**  
Variables that pass configuration data to containers at runtime.

**Exec**  
Running additional processes inside an already running container using `docker exec`.

**Exit Code**  
A numeric code returned when a container stops, indicating whether it terminated successfully (0) or with an error.

## F

**FROM**  
The Dockerfile instruction that specifies the base image to use for building a new image.

**Filesystem**  
The layered file system used by Docker, typically using overlay2 or aufs storage drivers.

## G

**Garbage Collection**  
The process of cleaning up unused Docker objects (images, containers, networks, volumes).

**GPU Support**  
Docker's ability to provide containers access to GPU resources for machine learning and computational workloads.

## H

**Health Check**  
A mechanism to test whether a container is working correctly, defined in Dockerfile or compose files.

**Host Network**  
A network mode where containers share the host's networking stack directly.

**Hub**  
Short for Docker Hub, the default public registry for Docker images.

## I

**Image**  
A read-only template containing a filesystem and metadata used to create containers.

**Image ID**  
A unique identifier for Docker images, typically shown as a short hash.

**Image Layer**  
Individual components that make up a Docker image, with each Dockerfile instruction creating a new layer.

**Init Process**  
Process ID 1 in a container, responsible for handling signals and reaping zombie processes.

## J

**JSON Log Driver**  
Docker's default logging driver that stores container logs in JSON format on the host.

## K

**Kubernetes**  
An open-source container orchestration platform that automates deployment, scaling, and management.

**Kill**  
Forcefully terminating a running container using SIGKILL signal.

## L

**Layer**  
A read-only filesystem change in a Docker image, created by each instruction in a Dockerfile.

**Link**  
Legacy method for connecting containers (deprecated in favor of user-defined networks).

**Log Driver**  
Plugin that determines where and how container logs are stored and managed.

## M

**Multi-arch Images**  
Container images that support multiple CPU architectures (x86_64, ARM, etc.).

**Multi-stage Build**  
Dockerfile feature allowing multiple FROM instructions to create optimized production images.

**Mount**  
Attaching storage (volumes, bind mounts, or tmpfs) to a container's filesystem.

**Microservices**  
Architectural pattern of building applications as small, independent services that communicate over APIs.

## N

**Namespace**  
Linux kernel feature providing process isolation (PID, network, mount, etc.) that containers use for isolation.

**Network**  
Docker's networking system that allows containers to communicate with each other and external systems.

**Node**  
A machine (physical or virtual) that runs Docker containers, often part of a Swarm or Kubernetes cluster.

## O

**Orchestration**  
Automated management of containerized applications across multiple hosts (scaling, updates, health monitoring).

**Overlay Network**  
Multi-host networking that enables containers on different hosts to communicate securely.

**OCI (Open Container Initiative)**  
Industry standard for container formats and runtimes that Docker implements.

## P

**Port Mapping**  
Exposing container ports to the host system or external networks using the -p flag.

**Pod**  
Kubernetes concept of a group of containers that share storage and network (not native to Docker).

**Process**  
Running instance of a program, with containers typically running a single main process.

**Pull**  
Downloading an image from a registry to the local machine.

**Push**  
Uploading an image from local machine to a registry.

## Q

**Quorum**  
Minimum number of manager nodes needed in a Docker Swarm cluster to maintain consensus.

## R

**Registry**  
A service for storing and distributing Docker images (public like Docker Hub or private).

**Replica**  
Multiple instances of a service running across a Swarm cluster for high availability.

**Repository**  
A collection of related Docker images, typically with different tags representing versions.

**Restart Policy**  
Rules defining when and how containers should be restarted automatically.

**Runtime**  
The component responsible for running containers (containerd, CRI-O, etc.).

**runc**  
The default OCI-compliant container runtime used by Docker and other container platforms.

## S

**Secret**  
Sensitive data (passwords, keys, certificates) managed securely in Docker Swarm mode.

**Service**  
In Docker Swarm, a definition of how containers should run across the cluster.

**Stack**  
A collection of services defined in a Compose file deployed to a Docker Swarm.

**Storage Driver**  
Component managing how image layers and container filesystems are stored (overlay2, aufs, etc.).

**Swarm**  
Docker's native clustering solution for managing multiple Docker hosts as a single unit.

## T

**Tag**  
A label applied to Docker images to identify different versions or variants.

**Task**  
Individual instance of a service running on a node in Docker Swarm.

**tmpfs**  
Temporary filesystem stored in memory, useful for sensitive or temporary data in containers.

## U

**Union Filesystem**  
Filesystem that overlays multiple directories to appear as a single filesystem, used in Docker's layered architecture.

**User-defined Network**  
Custom Docker networks created by users, providing better isolation and features than default networks.

## V

**Volume**  
Persistent data storage managed by Docker, independent of container lifecycle.

**Volume Driver**  
Plugin that handles how volumes are created and managed (local, NFS, cloud storage, etc.).

**VFS (Virtual File System)**  
Storage driver that doesn't use copy-on-write, copying entire layers (slower but more compatible).

## W

**Workload**  
Applications or services running in containers, often used in orchestration contexts.

## X

**X11 Forwarding**  
Technique for running GUI applications in containers by sharing the host's display.

## Y

**YAML**  
Human-readable data serialization standard used in Docker Compose files.

## Z

**Zombie Process**  
Defunct process that has completed execution but still has an entry in the process table.

---

## Docker Commands Quick Reference

### Container Management

- `docker run` - Create and start a container
- `docker start/stop/restart` - Control container state
- `docker ps` - List containers
- `docker exec` - Execute command in running container
- `docker logs` - View container logs
- `docker rm` - Remove container

### Image Management

- `docker build` - Build image from Dockerfile
- `docker pull/push` - Download/upload images
- `docker images` - List local images
- `docker rmi` - Remove images
- `docker tag` - Tag images
- `docker history` - Show image layers

### Network Management

- `docker network create/ls/rm` - Manage networks
- `docker network connect/disconnect` - Connect containers to networks

### Volume Management

- `docker volume create/ls/rm` - Manage volumes
- `docker volume inspect` - View volume details

### System Management

- `docker info` - System information
- `docker version` - Version information
- `docker system prune` - Clean up unused objects

---

## Docker Compose Keywords

### Service Configuration

- `build` - Build configuration
- `image` - Image to use
- `container_name` - Custom container name
- `ports` - Port mappings
- `volumes` - Volume mounts
- `environment` - Environment variables
- `depends_on` - Service dependencies
- `networks` - Network configuration
- `restart` - Restart policy

### Deploy Configuration (Swarm)

- `replicas` - Number of service instances
- `placement` - Placement constraints
- `resources` - Resource limits and reservations
- `update_config` - Rolling update configuration
- `restart_policy` - Service restart policy

---

## Common File Extensions

- `.yml/.yaml` - Docker Compose files
- `.dockerignore` - Files to ignore during build
- `Dockerfile` - Image build instructions
- `.env` - Environment variables file

---

## Status and State Terms

### Container States

- **Created** - Container exists but not started
- **Running** - Container is executing
- **Paused** - Container processes are suspended
- **Stopped** - Container has exited
- **Dead** - Container in non-recoverable state

### Image States

- **Dangling** - Images with no tags
- **Intermediate** - Images created during build process
- **Base** - Images used as foundation for other images

### Service States (Swarm)

- **Pending** - Service being scheduled
- **Running** - Service tasks are running
- **Complete** - Service has completed (for one-time tasks)
- **Failed** - Service tasks have failed

---

## Error Codes Reference

### Common Exit Codes

- `0` - Success
- `1` - General error
- `125` - Docker daemon error
- `126` - Container command not executable
- `127` - Container command not found
- `137` - Container killed (SIGKILL)
- `143` - Container terminated (SIGTERM)

### Build Error Types

- **Context error** - Issues with build context
- **Syntax error** - Dockerfile syntax problems
- **Resource error** - Insufficient resources
- **Network error** - Connectivity issues during build

---

## Networking Terms

- **Bridge** - Default network driver
- **Host** - Use host networking stack
- **None** - Disable networking
- **Overlay** - Multi-host networking
- **Macvlan** - Assign MAC addresses to containers
- **Internal** - Network with no external access

---

## Storage Terms

- **Named Volume** - Docker-managed volume with name
- **Anonymous Volume** - Docker-managed volume without name
- **Bind Mount** - Host directory mounted into container
- **tmpfs Mount** - Memory-based temporary filesystem

This glossary provides essential Docker terminology for quick reference while working with containers and orchestration platforms.
