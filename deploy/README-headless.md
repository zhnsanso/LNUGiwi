# GiWiFi Linux headless 版（WebUI）

在无图形界面的 64 位 Linux（树莓派 3B+ / 4 / 5、Zero 2 W、x86 软路由、小主机等）上通过浏览器完成校园网认证。

当前版本只做核心功能：**选择终端槽位 + 登录 / 注销 / 在线状态查询**。没有自动重连守护，也没有配置文件——凭据只保存在浏览器页面内存中，不做任何落盘，进程重启或页面刷新后需重新输入。

## 运行

```bash
tar -xzf GiWiFi-headless-linux-arm64.tar.gz   # x86 设备换成 x86_64
sudo install -m 0755 giwifi-headless /usr/local/bin/
giwifi-headless serve
```

默认监听 `0.0.0.0:8712`，同一局域网的手机或电脑打开 `http://树莓派IP:8712` 即可。

常用参数：

| 参数 | 说明 |
| --- | --- |
| `--host <地址>` | 监听地址，默认 `0.0.0.0` |
| `--port <端口>` | 监听端口，默认 `8712` |
| `--token <令牌>` | 启用访问令牌（URL 附加 `?token=...`）；也可用环境变量 `GIWIFI_TOKEN` |
| `--server <地址>` | 认证服务器兜底地址，默认 `http://100.100.9.2` |
| `--ac <名称>` | AC 名称兜底值，默认 `GiWiFi_lnsfHG` |

门户地址 / AC 名称 / 本机 IP 会在首次请求时通过 AC 劫持探测自动发现并覆盖兜底值。

## 开机自启（systemd）

```bash
sudo cp giwifi-headless.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now giwifi-headless
systemctl status giwifi-headless
```

建议在 unit 文件里启用 `Environment=GIWIFI_TOKEN=...`，否则同一网络内任何人都能打开页面并触发认证。

## 安全须知

- WebUI 走明文 HTTP，默认无鉴权。请只在可信局域网使用，或启用 `--token`。
- 凭据不落盘：页面刷新、关闭标签页或进程重启后即清除。
- 认证请求发往页面配置的校园网认证服务器；本工具不上传账号信息。

## 常见问题

- **`bind: address already in use`**：端口被占用，换 `--port` 或停掉占用进程。
- **页面能开但状态一直“未知”**：设备未连校园网、未认证且探测不可达时属正常；连上校园 Wi-Fi 后刷新页面再试。
- **32 位系统**：不提供 armv7 构建（Dart 官方已无 32 位 ARM SDK）。请使用 64 位系统。
- **需要无人值守自动重连**：当前版本不提供，可关注后续版本。
