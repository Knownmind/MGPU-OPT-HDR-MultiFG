# 轻量包必读：需要自备的运行时文件

本仓库是**轻量包**：为遵守 NVIDIA/AMD 的再分发许可，**不含**以下运行时二进制。请把它们放进 `Win64\mgpu\`（与 `mgpu.ini` 同级），桥才能启动 NR/插帧。

| 文件（放到 `Win64\mgpu\`） | 参考大小 | 参考 SHA256（可选，用于核对） | 从哪里来 |
|---|---|---|---|
| `nvngx_dlssnr.dll` | 276,162,560 B（DLSS-NR 310.9.16）/ 165,840,496 B（310.8） | `cdfa6c1ec784867182164c7836f324f087b5c9f374d0c9fe46f54999feabf3ed`（310.9.16） | **NVIDIA DLSS-NR 运行时/模型**：从你自己的合法来源取得（已安装的 DLSS 运行时、你之前获得的模型副本等）。本仓库不提供下载 |
| `_nvngx.dll` | 1,438,952 B | 由本机驱动决定 | **最省事**：`powershell -ExecutionPolicy Bypass -File tools\setup-driver.ps1 -GameDir "<游戏exe目录>" -Apply` 会从本机 DriverStore 复制 |
| `nvngx_dlssg.dll` | 7,506,544 B | — | **NVIDIA DLSS-G 运行时**：从你自己的合法来源取得（部分游戏/驱动/OPT 运行库自带） |
| `vendor_dlss.dll` | 35,400,248 B | — | 同上（NVIDIA vendor 运行库） |
| `vendor_gpu.dll` | 560,200 B | — | 同上 |

## 怎么检查文件放好了

```powershell
# 部署后自检（只读，退出码=FAIL 数）
powershell -ExecutionPolicy Bypass -File "<游戏exe目录>\check-deploy.ps1"
```

- 缺 `nvngx_dlssnr.dll`：日志 `[P4.1]` 报"PRIVATE NR snippet not found"或回退失败；
- 缺 `_nvngx.dll`：会回退到进程共享 core，与 OPT 同进程时可能 `FAIL_FeatureNotSupported`；优先用 `setup-driver.ps1 -Apply` 生成本机私有 core；
- 缺 `nvngx_dlssg.dll`：插帧不启动（`[FG]` 相关错误），NR 仍可用；
- 缺 `vendor_*.dll`：视游戏/运行时而定，可能影响 DLSS 输入或 NR 效果。

> 运行时文件受 NVIDIA/AMD 许可约束，本项目只做"放哪里/怎么核对"的说明，不提供下载、不再分发。
