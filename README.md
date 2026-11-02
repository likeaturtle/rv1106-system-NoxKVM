
<div align="center">
  <img alt="JetKVM Logo" src="https://jetkvm.com/logo-blue.png" height="40">

**rv1106 System**

[Website](https://jetkvm.com) • [Issues](https://github.com/jetkvm/kvm/issues) • [Docs](https://jetkvm.com/docs) • [Discord](https://jetkvm.com/discord)

</div>

JetKVM 固件的官方构建系统，可编译并定制 JetKVM 设备的每一处细节——从 bootloader 到应用程序。本仓库是一套完整的 SDK，用于构建适配 JetKVM 设备的固件镜像，并将 U-Boot、内核、根文件系统、媒体组件以及可选应用统一在一个仓库中管理。

---

## 快速开始

#### 1. 安装依赖

```bash
./install.sh
```

#### 2. 选择单板配置

```bash
./build.sh lunch project/cfg/BoardConfig_IPC/BoardConfig-NAND-NONE-RV1106_JETKVM_V2.mk
```

#### 3. 自动编译

```bash
./build.sh
```

这一条命令会完成 U-Boot、内核、根文件系统，以及为 JetKVM 设备配置的媒体与应用组件的构建，最终镜像将输出到 `output/image/`。

## 详细构建步骤

增量开发或调试时，可以单独构建各个组件：

### 构建 U-Boot

```bash
./build.sh clean uboot
./build.sh uboot
```

生成：

```
output/image/MiniLoaderAll.bin
output/image/uboot.img
```

### 构建内核

```bash
./build.sh clean kernel
./build.sh kernel
```

生成：`output/image/boot.img`

### 构建根文件系统

```
./build.sh clean rootfs
./build.sh rootfs
```

生成：`output/image/rootfs.img`

随后将包括 rootfs.img 在内的所有组件打包为最终 JetKVM 固件：

```bash
./build.sh firmware
```

### 构建媒体组件

```bash
./build.sh clean media
./build.sh media
```

生成的媒体相关库或驱动位于：`output/out/media_out`

### 构建参考应用

```bash
./build.sh clean app
./build.sh app
```

生成的应用二进制位于：`output/out/app_out`

> [!NOTE]  
> 参考应用可能依赖媒体组件的构建结果。

> [!TIP]  
> 若使用已编译好的 `jetkvm_app`，替换方法见 [二次开发修改内容注意事项.md](二次开发修改内容注意事项.md) 第十一节。

### 固件打包

```bash
./build.sh firmware
```

将各组件组装为可烧写的镜像，输出到 `output/image/`。

### 输出目录

构建完成后，`output/` 目录结构大致如下：

```
output/
├── image
│   ├── download.bin
│   ├── env.img
│   ├── idblock.img
│   ├── uboot.img
│   ├── boot.img
│   ├── rootfs.img
│   └── userdata.img
└── out
    ├── app_out
    ├── media_out
    ├── rootfs_xxx
    ├── S20linkmount
    ├── sysdrv_out
    └── userdata
```

- `image/` —— 用于烧写到 JetKVM 设备的最终固件镜像。
- `out/` —— 存放中间构建产物，如编译好的应用、媒体组件以及 rootfs 打包目录。

## 配置选项

所有用于定制构建的变量（CPU 架构、启动介质、分区布局、可选功能等）都在 cfg-all-items-introduction.txt 中有说明。

**几个常用示例：**

| 配置项                | 说明 |
|-------------------------|---------|
| **RK_ARCH**            | 构建 32 位（`arm`）或 64 位（`arm64`）固件。 |
| **RK_BOOT_MEDIUM**     | 指定存储介质：`emmc`、`spi_nor`、`spi_nand` 或 `slc_nand`。 |
| **RK_UBOOT_DEFCONFIG** | 指定 U-Boot 的 defconfig 文件。 |
| **RK_KERNEL_DEFCONFIG** | 指定内核的 defconfig 文件。 |
| **RK_KERNEL_DTS**      | 内核构建使用的目标 DTS（设备树）。 |
| **RK_PARTITION_CMD_IN_ENV** | 定义固件的分区布局。 |
| **RK_APP_TYPE**        | 决定打包哪些参考应用。 |
| **RK_ENABLE_WIFI**     | 为 JetKVM 固件启用 Wi-Fi 功能。 |
| **RK_CHIP**            | **不可修改**：不同芯片对应不同的 SDK。 |
| **RK_TOOLCHAIN_CROSS** | **不可修改**：定义交叉编译工具链。 |

完整的配置变量列表见 [cfg-all-items-introduction.txt](https://github.com/BuildJet/rv1106-sdk/blob/main/project/cfg-all-items-introduction.txt)

## 内核配置

开始修改内核配置：

```bash
cp ./arch/arm/configs/rv1106-jetkvm-v2_defconfig .config
make ARCH=arm menuconfig
```

配置完成后，按如下方式保存配置：

```bash
make ARCH=arm savedefconfig
cp defconfig ./arch/arm/configs/rv1106-jetkvm-v2_defconfig
```

## 贡献

欢迎社区贡献！无论是改进固件、新增功能还是完善文档，你的参与都很有价值。本仓库也有相应的规则与禁忌，请先仔细阅读本页内容与我们的[行为准则](/CODE_OF_CONDUCT.md)。

也请遵守行为准则，共同维护一个友好、建设性的社区氛围。

## 注意事项

### 避免从 Windows 拷贝代码

在 Windows 上移动源码可能破坏文件权限或符号链接。请始终在原生 Linux 环境中操作本代码库。

### macOS 默认文件系统不区分大小写

这会导致在 macOS 环境下 clone 本仓库后始终显示有文件变更。建议将仓库 clone 到区分大小写的文件系统挂载点中再进行编辑：

```sh
hdiutil create -type SPARSE -fs 'Case-sensitive Journaled HFS+' -size 10g -volname CaseSensitive ~/CaseSensitive.dmg.sparseimage
hdiutil attach ~/CaseSensitive.dmg.sparseimage
cd /Volumes/CaseSensitive

git clone git@github.com:jetkvm/rv1106-system.git
```

### 本仓库使用的部分库可能没有 arm64 版本

`g++-multilib`、`gcc-multilib` 等软件包并未发布到 amd64 的标准 debian apt 源中。你可能需要在 x86/amd64 机器上，或在使用 amd64 架构的虚拟机/devcontainer 中运行本 SDK。

祝构建顺利 —— 借助这套 SDK，你将完全掌控 JetKVM 固件，可针对自己的硬件、存储方案与定制应用需求进行裁剪。
