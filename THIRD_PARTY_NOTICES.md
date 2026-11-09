# Third-Party Notices

本仓库包含或依赖以下第三方组件。**本仓库/Release 不再分发任何 NVIDIA 或 AMD 运行时二进制**（DLSS-NR 模型、DLSS-G、`_nvngx.dll`、vendor 运行库、FSR 运行库等），由用户自备，见 `docs/RUNTIME-FILES.md`。

## 1. MGPU Bridge / Neural-coprocessor（上游）

- 项目：https://github.com/maohgad-web/Neural-coprocessor
- 作者：Marcelo Guibout
- 许可：MIT
- 说明：`Win64/nvngx.dll_mgpu_bridge.addon64` 是以上游 0.4.0 为基础的**定制构建**；上游 MIT 版权与许可声明随上游发布物保留。

## 2. ReShade 6.8

- 项目：https://reshade.me
- 作者：crosire / Patrick Mours
- 许可：BSD-3-Clause（Copyright (c) 2014 Patrick Mours）
- 说明：`Win64/dxgi.dll` 是未修改的 ReShade 6.8 add-on 版，按 BSD-3 再分发；完整许可文本见上游发布物。

## 3. NVIDIA DLSS 运行时（不随本仓库分发）

- 内容：`nvngx_dlssnr.dll`（NR 模型）、`nvngx_dlssg.dll`（DLSS-G）、`vendor_dlss.dll`、`vendor_gpu.dll`、`_nvngx.dll`
- 许可：NVIDIA 软件许可；**本仓库/Release 不包含这些文件**。用户需从自己的合法来源（已安装的驱动/游戏、或自己合法获得的副本）取得，并遵守 NVIDIA 许可。

## 4. AMD FidelityFX / OptiScaler（不随本轻量发布分发）

- OptiScaler：https://github.com/optiscaler/OptiScaler ，按其自身许可；
- AMD FidelityFX 运行库：按 AMD 许可；
- 本轻量发布不包含上述二进制。

## 5. 其它

- 本仓库不包含任何游戏文件；游戏内容版权归各自权利人。
