# DockAI

## What it is and why

DockAI builds a Docker image from an existing base image and adds AI-assisted development tools for the normal user inside the container.

The goal is to keep the base image separate from the AI tooling. You start with a base image that already contains your main development environment, and DockAI creates a derived image that keeps that environment while adding tools such as Bun, pnpm, context-mode, context7-mcp, and RTK.

This avoids installing the same tools by hand in every container and makes the resulting environment easier to reproduce.

## Description

This repository contains these files:

- `Dockerfile.ai-tools`: defines the derived image. The root phase installs system packages, Node.js, Corepack, and pnpm. The user phase installs AI tools under the `HOME` directory defined by the base image for the selected user.
- `build_ai_image.sh`: runs `docker buildx build` with the required build arguments.
- `install_ai_tools_root.sh`: installs system dependencies and prepares pnpm.
- `install_ai_tools_user.sh`: installs user-level tools and writes the required `PATH` entries into the selected shell rc file.
- `.pre-commit-config.yaml`: configures standard checks, shell formatting with `shfmt`, and Conventional Commits validation.

### Requirements

You need Docker with `buildx` available on the machine that builds the image.

The base image must contain the user you want to use as the main container user. DockAI uses `dev` as the default user.

### Shell startup files

The user installer does not write the full `PATH` setup directly into the selected shell rc file. Instead, it creates a companion file by appending `.ai` to the rc file name. For example, if the selected rc file is `${HOME}/.bashrc.user`, the installer creates `${HOME}/.bashrc.user.ai`.

That generated `.ai` file exports `BUN_INSTALL`, exports `PNPM_HOME`, and prepends the user-local tool directories to `PATH`.

The selected rc file only receives one source line:

```bash
[ -f "${HOME}/.bashrc.user.ai" ] && . "${HOME}/.bashrc.user.ai"
```

If you pass `.bashrc` as the rc file, the generated file becomes `${HOME}/.bashrc.ai` and the source line is added to `${HOME}/.bashrc` instead.

### Step by step

1. Enter the project directory:

   ```bash
   cd dockai
   ```

2. Build a derived image:

   ```bash
   ./build_ai_image.sh <base_image> <target_image>
   ```

3. If the main user in the base image is not `dev`, pass it as the third argument:

   ```bash
   ./build_ai_image.sh ubuntu:24.04 my-ai-image:latest developer
   ```

4. Run the resulting image:

   ```bash
   docker run --rm -it my-ai-image:latest
   ```

5. Inside the container, verify that the tools are available:

   ```bash
   node --version
   pnpm --version
   bun --version
   rtk --version
   context-mode doctor
   ```

## Examples

Build an image using the default options:

```bash
./build_ai_image.sh my-base:latest my-base-ai:latest
```

Build an image for a base image where the main user is named `developer`:

```bash
./build_ai_image.sh my-base:latest my-base-ai:latest developer
```

Use `.bashrc` instead of `.bashrc.user` for the generated `PATH` entries:

```bash
./build_ai_image.sh my-base:latest my-base-ai:latest developer .bashrc
```

Use a different build context:

```bash
./build_ai_image.sh my-base:latest my-base-ai:latest developer .bashrc /path/to/dockai
```

Install and run the pre-commit hooks:

```bash
pre-commit install
pre-commit install --hook-type commit-msg
pre-commit run -a
```

If you are working directly on the `main` branch, the `no-commit-to-branch` hook will block the commit. Create a working branch before committing:

```bash
git switch -c improve-dockai
```
