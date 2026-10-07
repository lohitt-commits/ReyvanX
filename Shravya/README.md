# Shravya: ReyvanX run log

A step-by-step record of running ReyvanX on a Windows laptop, without changing any ReyvanX code. Each step says what was done, where, and whether it worked.

Machine: ASUS VivoBook S15, Windows 10 Home, 7.9 GB RAM.

## Status

| # | Step | Result |
|---|---|---|
| 1 | Clone ReyvanX and make the `ReyvanX_Shravya` branch | Done |
| 2 | Add `Shravya/README.md` and push the branch | Done |
| 3 | Keep Claude and AI tool files out of Git | Done |
| 4 | Install Docker Desktop | Waiting: needs an Administrator PowerShell |
| 5 | Run ReyvanX in Docker and open the dashboard | Not started |
| 6 | Repeat on AWS EC2 | Not started |

## Steps done

### 1. Clone and branch

Run in PowerShell:

```
cd "D:\ReyvanX Project"
git clone https://github.com/lohitt-commits/ReyvanX.git
cd ReyvanX
git checkout -b ReyvanX_Shravya
git config user.name "shravya"
git config user.email "shravya@test.de"
```

Result: the branch starts from `origin/main`.

### 2. Add this README and push

```
git add Shravya/README.md
git commit -m "testing"
git push -u origin ReyvanX_Shravya
```

Result: the branch is on GitHub at https://github.com/lohitt-commits/ReyvanX/tree/ReyvanX_Shravya. Lohit had to add Shravya as a collaborator first. Git Credential Manager asks for a browser sign-in on the first push.

### 3. Keep AI tool files out of Git

Added to `.gitignore`: `.claude/`, `CLAUDE.local.md`, `.mcp.json`, `claude-*.log`, `netbird-clone.log`, `netbird-upstream/`.

### 4. Limit WSL memory

Docker Desktop runs on WSL 2. To stop it using all 8 GB, create `C:\Users\shrav\.wslconfig`:

```
[wsl2]
memory=4GB
processors=2
swap=4GB
```

## What did not work

- **Compiling the server from source in WSL** (`go build ./combined`, Go 1.26.8). It ran for over 10 minutes without finishing on this laptop and was stopped. Do not repeat it. Use the prebuilt Docker images instead.
- **Pushing from the Claude session.** Git could not open a browser sign-in there. The push worked once the credential prompt was allowed.

## Next: install Docker Desktop (needs Administrator)

1. Right-click Start, choose **PowerShell (Admin)**.
2. Run `winget install -e --id Docker.DockerDesktop`.
3. Restart if asked, open Docker Desktop, wait for "Engine running".
4. Check with `docker version`.

## Then: run ReyvanX in Docker

Mahesh's branch `origin/docker-containerization` has `deploy/RUNNING_LOCALLY.md` and `deploy/local/`. It was validated on a Mac. Its start command points at a generated `docker-compose.yml` that is not in the repo, so the first job is to generate that file with `infrastructure_files/getting-started.sh`. Steps and results will be added here as they are tried.
