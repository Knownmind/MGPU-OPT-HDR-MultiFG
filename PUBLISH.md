# 发布到 GitHub（维护者操作）

> **GitHub 账号**：`Knownmind`　**建议仓库名**：`MGPU-11.9`（可在网页改名，下面的命令同步改）

## 0. 前置

- GitHub 账号；本机已装 git（2.56+）与可选 GitHub CLI（`winget install GitHub.cli`，然后 `gh auth login`）。

## 1. 建仓库

GitHub 网页：New repository → 名称随意（如 `MGPU-11.9`）→ Public → 不要初始化 README/LICENSE（本目录已有）。

## 2. 推仓库（在本目录执行）

```bash
git init
git add .
git commit -m "MGPU 11.9 (R41x13j) - free share"
git branch -M main
git remote add origin https://github.com/Knownmind/MGPU-11.9.git
git push -u origin main
```

## 3. 发 Release（附件用轻量包 zip）

```bash
# 先在本机生成发布 zip（见下），或直接用 _release-assets\ 里已生成的
gh release create v11.9 ^
  "_release-assets\MGPU-11.9-lite.zip" ^
  "_release-assets\MGPU-11.9-lite.zip.sha256.txt" ^
  --title "MGPU 11.9（R41x13j）轻量包 · 免费分享" ^
  --notes-file RELEASE_NOTES.md
```

或网页：Releases → Draft a new release → Tag `v11.9` → 上传 zip + `.sha256.txt`，说明用 `RELEASE_NOTES.md` 内容。

## 4. 生成发布 zip

```powershell
# 在仓库根目录执行：把除 .git / _release-assets 外的内容压成 zip
powershell -NoProfile -Command "Compress-Archive -Path (Get-ChildItem -Force | Where-Object { $_.Name -notin '.git','_release-assets' }).FullName -DestinationPath '_release-assets\MGPU-11.9-lite.zip' -CompressionLevel Optimal -Force"
cd _release-assets
Get-FileHash MGPU-11.9-lite.zip -Algorithm SHA256 | ForEach-Object { $_.Hash.ToLower() + '  MGPU-11.9-lite.zip' } | Set-Content MGPU-11.9-lite.zip.sha256.txt -Encoding ASCII
```

## 5. 校验清单

- [ ] `git status` 干净、没有 `_release-assets/`、没有 `Win64/mgpu/*.dll`；
- [ ] 仓库里 `README.md` 路径无本机绝对路径；
- [ ] Release 附件 = `MGPU-11.9-lite.zip` + `.sha256.txt`；
- [ ] `SHA256SUMS.txt` 与仓库文件一致。
