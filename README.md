# 与你食光 · iPhone

SwiftUI 原生健身营养记录 App，最低 iOS 17。支持自动或手动营养目标、家庭份量记餐、体重日期与照片记录，以及运动服漫画角色导航。

## 取得爱思签名用的 IPA

原生源码推送后，GitHub Actions 的 **Build unsigned iPhone IPA** 会先运行模拟器测试，通过后生成未签名的 iPhone IPA。也可在 Actions 页面手动运行。

构建成功后，下载 `NutritionDiary-unsigned-iPhone-IPA` 附件并解压，再用爱思助手签名安装。构建不需要 Apple ID 或签名证书。详细步骤与限制见 [安装说明](INSTALL-IPHONE.md)。

日记和照片保存在设备内。AI 估算需要单独配置可访问的 HTTPS 服务；默认未配置。此仓库不含个人记录或服务密钥。

当前为首版工程，原生编译、签名和真机体验以实际构建及设备验证结果为准。
