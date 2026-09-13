# 自定义 Finder 菜单

`custom_menu.json` 是菜单根节点数组；顺序就是显示顺序。示例将 VS Code、Warp 平铺，次要动作放在“更多”，TXT / Markdown 放在第三级“新建文件”。

## 使用

**设置 → 通用 → 高级菜单布局** 下有四个按钮：

| 按钮 | 行为 |
| --- | --- |
| 打开配置 | 文件不存在时基于当前已配置项目生成可用示例，然后用默认关联应用打开；已存在则仅打开。**两者都不改动文件内容** |
| 在访达中显示 | 同上，末步改为在访达中选中文件 |
| 应用自定义菜单 | 立即重读并生效，不必等心跳；**不修改文件** |
| 恢复默认布局 | 删除 `custom_menu.json` 回到默认布局，删除前把副本保留为 `custom_menu.backup.json` |

生成与打开都不会覆盖已有文件（包括尚未编辑完成的 JSON）。

**生效方式有两条，结果相同**：保存修改后，扩展每 10 秒的心跳会让主程序重读文件，最多 10 秒自动生效；点「应用自定义菜单」则立刻生效。后者只是省去等待，**不是必须的步骤**。

设置页顶部会显示当前状态（未启用 / 已启用 / 配置无效）。配置无效时**会列出具体哪一项出错**，例如 `[2.1] app reference '/Applications/Warp.app' matched 0 enabled items` —— 方括号是菜单项路径，`[2.1]` 指第 2 项里的第 1 项。

示例将当前应用和动作平铺，文件模板与常用目录放入“更多”下的子菜单。可直接把 JSON 交给 AI 助手调整结构。若尚未配置任何项目，会生成空的“更多”子菜单。

以下是手动安装仓库示例的方法：

1. 先在 RClick 设置中添加 VS Code、Warp，启用 Copy Path、TXT 和 Markdown。应用路径要与配置完全一致；不存在、禁用或有歧义的引用会导致整份配置回退，控制台会记录原因。
2. 将本目录的 `custom_menu.json` 复制到 App Group 根目录：

   ```sh
   cp examples/custom_menu.json "$HOME/Library/Group Containers/group.cn.wflixu.RClick/custom_menu.json"
   ```

   目录应由正常签名并运行过的 RClick 创建。实际读取使用 `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`；若改变 App Group 标识，使用对应容器。
3. 保持主程序运行。扩展每 10 秒心跳会触发主程序重新读取；等待一次心跳后重新打开右键菜单，或重启 RClick。已展开的菜单不会即时重绘。
4. 删除或移走该文件即可恢复原来的分类顺序与折叠设置（设置里的「恢复默认布局」按钮做的也是这件事，还会留一份备份）。JSON 错误、结构错误、无法读取或引用不唯一也会回退到默认布局，并在设置中显示具体原因；`[]` 则有意显示空菜单。

## 节点

| type | 字段 | 含义 |
| --- | --- | --- |
| `item` | `itemType` + 一个引用字段，可选 `title` / `icon` | 引用已配置项目，保留原来的点击逻辑 |
| `submenu` | `title`、`children`，可选 `icon` | 自定义子菜单，可递归嵌套 |
| `separator` | 无其他字段 | 分隔线 |

`itemType` 与引用字段：

- `app`：`appPath`（精确绝对路径，例如 `/Applications/Warp.app`）或持久化 `id`。
- `action`：`id`，例如 `copy-path`、`delete-direct`、`hide`、`unhide`、`airdrop`。必须在设置中启用。
- `new-file`：`fileExtension`（包含点，例如 `.txt`）或持久化 `id`。同扩展名有多个模板时必须用 `id`。
- `common-dir`：`id`，内置值包括 `home`、`desktop`、`documents`、`downloads`、`applications`；须先打开常用目录开关。

一个叶子只能使用一种引用方式。自定义项目 ID 来自现有 SwiftData 配置；没有新增 ID 编辑界面。标题原样显示，图标使用扩展内的 Asset 名称或 SF Symbol（例如 `folder`）；省略时叶子沿用原图标，无效图标不会阻止菜单构建。

> ⚠️ **截图里的文案是自定义标题，不是 App 内置文案。** `screenshots/` 预览中的“隐藏选中文件”“显示隐藏文件”“直接删除 (绕过废纸篓)”等字样，是作者在 JSON 里用 `title` 字段手写的说明性标题。不写 `title` 时显示的是 App 的实际文案：隐藏 / 显示 / 复制路径 / 直接删除 / AirDrop。若以为是内置文案而照抄，会得到一份看起来“官方”实则自造的菜单。

配置只控制布局：未列出的项目不显示，原有折叠开关在自定义布局生效时不参与排列。应用参数、文件模板、权限处理继续由主程序现有配置与执行链负责，JSON 不定义命令或修改参数执行语义。

## 实现与验证

`Shared/CustomMenu.swift` 定义共享 `Codable` 模型、引用校验与递归 NSMenu 构建；`MenuService` 在原有配置推送时读取文件，解析为稳定 ID 后放入可选 `MenuConfigPayload.customMenu`。扩展复用旧菜单的四类叶子工厂和点击处理器，保留 ID、类型、Finder 目标路径及触发来源。此模型可作为以后树形编辑 UI 的存储格式，无需迁移现有业务实体。

`RClickTests/CustomMenuTests.swift` 使用同一示例验证解析、三级 NSMenu 结构与叶子绑定；`CustomMenuStatusTests` 验证三态区分（缺文件 / `[]` / 无效）、错误消息定位（`[1.1]`）与删除时保留备份；`ActionServiceTests` 验证模板 ID / 路径经过保存与重载仍保持一致。测试不等同于签名安装后的 Finder 实机验收。

本地验证命令：

```sh
xcodebuild -project RClick.xcodeproj -scheme RClick -configuration Release
xcodebuild -project RClick.xcodeproj -scheme RClick -configuration Debug -destination 'platform=macOS' test
```

若 Fork 后尚未配置自己的签名团队 / provisioning profile，可在命令末尾加 `CODE_SIGNING_ALLOWED=NO` 验证编译与单元测试。关闭签名不能替代 Finder 扩展的正常签名、安装和实机验证；仓库仍保留原来的签名设置。
