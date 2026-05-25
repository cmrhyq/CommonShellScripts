# CommonShellScripts

常用 Shell 脚本集合，覆盖系统运维、安全防护、部署发布、监控告警、网络检测等日常场景。

面向 CentOS 7/8/Stream 系统，所有脚本遵循统一规范：
- `#!/bin/bash` + `set -euo pipefail` 安全模式
- 完整的参数校验和 usage 提示
- 带时间戳的日志输出
- 变量双引号包围，防止分词问题

## 目录结构

| 序号 | 目录 | 说明 | 脚本数 |
|------|------|------|--------|
| 1 | System | 系统运维与安全脚本 | 8 |
| 2 | docker | Docker容器相关脚本 | 3 |
| 3 | elastic | Elasticsearch/Kibana相关脚本 | 1 |
| 4 | mysql | MySQL数据库相关脚本 | 1 |
| 5 | git | Git批量操作与统计脚本 | 3 |
| 6 | backup | 文件与数据库备份脚本 | 3 |
| 7 | deploy | 应用部署与回滚脚本 | 3 |
| 8 | monitor | 系统监控与告警脚本 | 3 |
| 9 | network | 网络检测与诊断脚本 | 3 |
| 10 | log | 日志管理与分析脚本 | 3 |
| 11 | user | 用户管理与审计脚本 | 2 |
| 12 | cron | 定时任务管理脚本 | 2 |

## 脚本详情

### System - 系统运维与安全

| 脚本 | 功能 | 用法 |
|------|------|------|
| scanPort.sh | 扫描异常登录IP并用iptables封禁 | `sudo bash scanPort.sh [threshold]` |
| shieldIP.sh | 分析Nginx日志屏蔽高频攻击IP | `sudo bash shieldIP.sh [log_file] [threshold]` |
| scan.sh | GScan主机安全扫描并邮件报告 | `bash scan.sh [email]` |
| systemInspection.sh | 主机全方位巡检（CPU/内存/磁盘/网络/服务） | `bash systemInspection.sh` |
| createFolder.sh | 批量创建带子目录结构的文件夹 | `./createFolder.sh <path> <prefix>` |
| moveFile.sh | 按日期和文件名前缀移动文件 | `./moveFile.sh <date>` |
| renameFile.sh | 批量重命名文件（前缀/后缀截取） | `./renameFile.sh <mode> <pattern>` |
| openvpn/manager.sh | OpenVPN服务管理 | `./manager.sh <start\|stop\|restart\|status\|log>` |

### docker - Docker容器管理

| 脚本 | 功能 | 用法 |
|------|------|------|
| copyConfig.sh | 从容器复制Logstash配置到本地 | `./copyConfig.sh <container_id> [target_dir]` |
| logstash.sh | 创建Logstash容器 | `./logstash.sh [version] [name]` |
| oracle/initOraclePermission.sh | 初始化Oracle用户组和权限 | `sudo bash initOraclePermission.sh` |

### elastic - Elasticsearch

| 脚本 | 功能 | 用法 |
|------|------|------|
| createIndexForKibana.sh | 每月自动创建/删除Kibana索引 | `./createIndexForKibana.sh [add\|del] [date]` |

### mysql - MySQL数据库

| 脚本 | 功能 | 用法 |
|------|------|------|
| exportData.sh | 批量导出MySQL数据库 | `./exportData.sh <username> <password>` |

### git - Git操作

| 脚本 | 功能 | 用法 |
|------|------|------|
| batchPull.sh | 批量拉取多个Git仓库 | `./batchPull.sh [parent_dir] [branch]` |
| cleanBranches.sh | 清理已合并的本地分支 | `./cleanBranches.sh [main_branch]` |
| gitStats.sh | Git提交统计（按作者/日期） | `./gitStats.sh [since] [until] [author]` |

### backup - 备份管理

| 脚本 | 功能 | 用法 |
|------|------|------|
| backupFiles.sh | 文件/目录压缩备份（带轮转） | `./backupFiles.sh <source> [backup_dir] [keep_days]` |
| backupMysql.sh | MySQL全量备份（支持单库/全库） | `./backupMysql.sh [-u user] [-p pass] [-d db]` |
| backupRotate.sh | 备份文件轮转管理 | `./backupRotate.sh <dir> [-d days] [-n count]` |

### deploy - 部署发布

| 脚本 | 功能 | 用法 |
|------|------|------|
| deploy.sh | 通用应用部署（拉代码/编译/备份/重启） | `./deploy.sh <app_name> [options]` |
| healthCheck.sh | 服务健康检查（HTTP/TCP/进程） | `./healthCheck.sh <type> <target>` |
| rollback.sh | 快速回滚到上一版本 | `./rollback.sh <app_name> [-v version]` |

### monitor - 监控告警

| 脚本 | 功能 | 用法 |
|------|------|------|
| diskAlert.sh | 磁盘空间监控告警 | `./diskAlert.sh [-t threshold] [-m email]` |
| processMonitor.sh | 进程存活监控（自动拉起） | `./processMonitor.sh <process> [-s service]` |
| resourceReport.sh | 系统资源使用报告 | `./resourceReport.sh [-o output] [-m email]` |

### network - 网络工具

| 脚本 | 功能 | 用法 |
|------|------|------|
| checkConnect.sh | 批量连通性检测（ping/TCP） | `./checkConnect.sh <hosts_file> [-p port]` |
| portScan.sh | 批量端口扫描 | `./portScan.sh <host> [-p ports]` |
| dnsLookup.sh | DNS批量查询与对比 | `./dnsLookup.sh <domains> [-s dns_servers]` |

### log - 日志管理

| 脚本 | 功能 | 用法 |
|------|------|------|
| logRotate.sh | 日志切割与归档压缩 | `./logRotate.sh <log_file> [-s size_MB]` |
| logAnalyze.sh | 日志关键字分析与统计 | `./logAnalyze.sh <log_file> [-k keywords]` |
| logClean.sh | 清理N天前的日志文件 | `./logClean.sh [-d dirs] [-k days]` |

### user - 用户管理

| 脚本 | 功能 | 用法 |
|------|------|------|
| batchCreateUser.sh | 从CSV批量创建系统用户 | `sudo ./batchCreateUser.sh <csv_file>` |
| userAudit.sh | 用户安全审计（空密码/过期/不活跃） | `sudo ./userAudit.sh [-d days] [-o output]` |

### cron - 定时任务

| 脚本 | 功能 | 用法 |
|------|------|------|
| cronManager.sh | 定时任务管理（增删改查） | `./cronManager.sh <list\|add\|remove\|backup>` |
| cronBackup.sh | 备份所有crontab和系统cron配置 | `sudo ./cronBackup.sh [backup_dir]` |

## 使用说明

1. 克隆仓库：
```bash
git clone <repo_url> && cd CommonShellScripts
```

2. 赋予执行权限：
```bash
chmod +x **/*.sh
```

3. 运行脚本前查看帮助：
```bash
./deploy/deploy.sh --help
```

## 注意事项

- 部分脚本需要 `root` 权限（如 iptables、用户管理等），请使用 `sudo` 执行
- 首次使用前请修改脚本顶部的配置变量（邮箱、路径等）
- 建议在测试环境验证后再用于生产环境
- 使用 `--dry-run`（支持的脚本）可预览操作而不实际执行
