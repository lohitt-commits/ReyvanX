# Shravya workspace

This folder holds Shravya's freelance work on the ReyvanX test setup: Docker, Kubernetes and AWS load balancing, using a small stand-in app instead of NetBird.

Everything outside this folder is the unchanged ReyvanX source, kept in sync with `main`.

## Folders

| Folder | Contents |
|---|---|
| docs | Notes, decisions and the written record of each step |
| app | The stand-in test app and its Dockerfile |
| docker | Docker and Compose files |
| k8s/local | Kubernetes files for the local kind cluster |
| k8s/aws | Kubernetes files for EC2 and EKS |
| aws | AWS setup files, such as the EKS cluster definition |
| monitoring | Alert rules and dashboards |
| load-tests | Load test scripts |
| scripts | Helper scripts |
| mac-work | Earlier lab work copied over from the Mac |

## Keep this branch in sync with ReyvanX main

```
git fetch origin
git merge origin/main
git push
```

Run these from the `ReyvanX_Shravya` branch. Only this folder is edited here, so merges should not conflict.
