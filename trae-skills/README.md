# gstack for Trae IDE

这是 [gstack](https://github.com/boommanpro/gstack) AI工程工作流项目针对 Trae IDE 平台的适配版本。

## 改造概述

本次改造将gstack从Claude Code平台适配到Trae IDE平台，主要工作包括：

### 1. 目录结构

```
trae-skills/
├── install.sh    # 一键安装脚本
├── sync.sh       # 版本同步脚本
└── README.md     # 本文档
```

安装后会生成：
```
trae-skills/
├── gstack/                    # 根技能（包含浏览器自动化）
│   ├── SKILL.md              # 技能定义文件
│   ├── bin/                  # CLI工具（符号链接）
│   ├── browse/               # 浏览器二进制（符号链接）
│   └── ETHOS.md              # 设计哲学文档
├── gstack-review/            # PR审查技能
├── gstack-ship/              # 发布工作流技能
├── ... 更多技能
```

### 2. 与原始Claude技能的差异

| 特性 | Claude Code | Trae IDE |
|------|-------------|----------|
| 技能目录 | `~/.claude/skills/gstack` | `./trae-skills/` |
| 路径引用 | 硬编码路径 | 环境变量 + 相对路径 |
| Frontmatter | 完整字段 | 仅 name + description |
| 安装方式 | `./setup --host claude` | `./install.sh` |

### 3. 核心修改

以下文件已修改以支持Trae平台：

- `scripts/resolvers/types.ts` - 添加 `trae` 到 `Host` 类型
- `scripts/gen-skill-docs.ts` - 添加 Trae 主机检测
- `setup` - 添加 `--host trae` 选项
- `package.json` - 添加 `trae:install` 和 `trae:sync` 脚本

## 安装方法

### 方法一：一键安装（推荐）

```bash
cd trae-skills
chmod +x install.sh
./install.sh
```

### 方法二：通过主setup脚本

```bash
./setup --host trae
```

### 方法三：通过npm脚本

```bash
bun run trae:install
```

## 在Trae IDE中配置

安装完成后，在Trae IDE中配置技能路径：

1. 打开 Trae IDE 设置（`Cmd+,` 或 `Ctrl+,`）
2. 导航到 Skills/Agents 配置
3. 添加技能目录路径：
   ```
   /path/to/gstack/trae-skills
   ```

或设置环境变量：
```bash
export GSTACK_ROOT="/path/to/gstack/trae-skills/gstack"
export GSTACK_BIN="/path/to/gstack/trae-skills/gstack/bin"
export GSTACK_BROWSE="/path/to/gstack/trae-skills/gstack/browse/dist"
```

## 版本同步

当原始gstack项目更新时，运行同步脚本：

```bash
cd trae-skills
./sync.sh
```

强制同步：
```bash
./sync.sh --force
```

## 可用技能

| 技能名称 | 描述 |
|----------|------|
| `gstack` | 根技能，包含浏览器自动化和QA测试 |
| `gstack-review` | PR审查，发现CI无法检测的bug |
| `gstack-ship` | 完整发布流程 |
| `gstack-qa` | 打开真实浏览器，发现并修复bug |
| `gstack-design-review` | 设计审查 + 修复循环 |
| `gstack-plan-ceo-review` | CEO级产品审查 |
| `gstack-plan-eng-review` | 架构、数据流、边缘情况审查 |
| `gstack-office-hours` | YC办公时间模拟 |
| `gstack-debug` | 系统性根因调试 |
| `gstack-retro` | 周回顾和团队分析 |
| `gstack-browse` | 无头浏览器自动化 |
| ... 更多技能 | |

## 故障排除

### 问题：bun 未安装

```bash
curl -fsSL https://bun.sh/install | bash
```

### 问题：Playwright Chromium 未安装

```bash
cd /path/to/gstack
bunx playwright install chromium
```

### 问题：技能路径未识别

- 检查 Trae IDE 设置中的技能路径配置
- 确保环境变量正确设置
- 重启 Trae IDE

## 许可证

MIT License - 详见 [LICENSE](../LICENSE) 文件
