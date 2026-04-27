# LanCtrl Web 控制台

这个目录是局域网 Web 控制台的独立前端项目。

PC 端 Tauri/Axum 只负责托管这里的静态资源和提供 `/web/api/*`、`/web/ws`。Web 控制台自身维护页面状态、简单路由和渲染逻辑，避免和 PC 端桌面 App 的 Vue 项目混在一起。

