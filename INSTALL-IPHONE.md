# 通过爱思助手签名安装

已生成 `NutritionDiary-unsigned.ipa`（1.0 / build 1，iOS 17+）。2026-10-16 云端构建通过 7 项原生测试、真机编译、arm64 与压缩包完整性检查。[成功构建记录](https://github.com/YRYYL2333/nutrition-diary/actions/runs/38839592038)。本地文件位于本项目输出目录上一级；也可从构建结果下载 `NutritionDiary-unsigned-iPhone-IPA` 附件并解压。此 IPA 仍需用爱思签名。

`Preview.html` 是网页预览，工程 ZIP 是源码，不能直接导入爱思安装。

## 在没有 Mac 的电脑上准备安装包

1. 本项目已上传到用户授权公开的 [nutrition-diary](https://github.com/YRYYL2333/nutrition-diary) 仓库。自行建立副本时，将原生源码包内容放到仓库根目录，确保根目录直接包含 `NutritionDiary.xcodeproj`、`NutritionDiary`、`NutritionDiaryTests` 和 `.github`。
2. 上传原生源码后会自动运行 `Build unsigned iPhone IPA`；也可在 Actions 手动运行。流程先运行模拟器测试，通过后才生成真机 IPA。构建使用 GitHub 的 macOS 环境，无需向仓库提供 Apple ID、证书或签名密码。云端运行受自己账户的 Actions 额度与计费设置约束。`iOS simulator checks` 保留为单独检查入口。
3. 构建成功后，下载结果中的 `NutritionDiary-unsigned-iPhone-IPA` 附件并解压，取得 `NutritionDiary-unsigned.ipa`。失败时需先修复构建错误，不能把源码 ZIP 改名为 IPA。

## 在爱思中签名

连接 iPhone，按照你当前使用的爱思助手版本，在 IPA 签名中添加 `NutritionDiary-unsigned.ipa`，使用你自己的 Apple ID 或证书完成签名，再安装签名后的文件。设备和签名身份需匹配；具体可用性及有效期以当前签名方式和爱思提示为准。[爱思官方教程](https://www.i4.cn/news_detail_38195.html)

首版最低系统为 iOS 17。安装后需实际核对：相机权限、照片选择、首次目标设置、记餐保存、体重记录以及退出后重开。网页记录不会自动转入原生 App。AI 仍需配置手机可访问的 HTTPS 服务，手机上的 `127.0.0.1` 不能连接电脑上的代理。

本流程已生成并验证未签名真机包；爱思签名和手机运行尚未验证。当前 AI 文字和照片识别需要另外配置服务，不会直接调用手机上的 ChatGPT。
