Win64\mgpu\  ——  NVIDIA 运行时目录（本轻量包不含这些文件）

请按 docs\RUNTIME-FILES.md 把下列文件放进本目录（与 Win64\mgpu.ini 同级）：
  - nvngx_dlssnr.dll   （DLSS-NR 模型，310.9.16 / 310.8）
  - _nvngx.dll         （私有 NGX core；可跑 tools\setup-driver.ps1 -Apply 从本机 DriverStore 生成）
  - nvngx_dlssg.dll    （DLSS-G 运行时）
  - vendor_dlss.dll
  - vendor_gpu.dll

放好后跑一次 "<游戏exe目录>\check-deploy.ps1" 自检。
这些文件受 NVIDIA 许可约束：本仓库不提供下载、不再分发。
