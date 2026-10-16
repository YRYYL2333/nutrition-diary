import SwiftUI

@main struct NutritionDiaryApp: App {
    @StateObject private var store = DiaryStore()
    var body: some Scene { WindowGroup { ContentView().environmentObject(store).tint(Theme.rose) } }
}
enum Theme {
    static let rose = Color("AccentColor")
    static let paper = Color("Paper")
    static let teal = Color("Teal")
}

struct ContentView: View {
    @EnvironmentObject var store: DiaryStore
    @State private var adding = false
    @State private var settingUp = false
    @State private var selectedTab = "today"
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        TabView(selection:$selectedTab) {
            NavigationStack { TodayView(adding:$adding) }.tag("today").toolbar(.hidden,for:.tabBar)
            NavigationStack { RecordsView() }.tag("record").toolbar(.hidden,for:.tabBar)
            NavigationStack { WeightHistory().navigationTitle("体重日记") }.tag("weights").toolbar(.hidden,for:.tabBar)
            NavigationStack { SettingsView() }.tag("profile").toolbar(.hidden,for:.tabBar)
        }
        .safeAreaInset(edge:.bottom,spacing:0) {
            HStack(alignment:.bottom,spacing:0) {
                characterTab("今天",image:"NutritionHero",value:"today")
                characterTab("饮食",image:"MealReview",value:"record")
                Button { adding = true } label: { VStack(spacing:6) { Image(systemName:"plus.circle").font(.system(size:42,weight:.regular)).foregroundStyle(Theme.rose); Text("记一餐").font(.caption) }.frame(maxWidth:.infinity,minHeight:typeSize.isAccessibilitySize ? 44 : 90) }.accessibilityLabel("记一餐")
                characterTab("体重",image:"Stretching",value:"weights")
                characterTab("我的",image:"Recovery",value:"profile")
            }.padding(.horizontal,12).padding(.top,5).background(Theme.paper).overlay(alignment:.top) { Divider() }
        }
        .sheet(isPresented:$adding) { MealEditor() }
        .sheet(isPresented:$settingUp) { ProfileEditor(profile:store.state.profile ?? Profile()) }
        .onAppear { settingUp = store.state.profile == nil }
        .alert("数据操作未完成",isPresented:Binding(get:{store.error != nil},set:{if !$0 {store.error = nil}})) { Button("知道了") { store.error = nil } } message: { Text(store.error ?? "") }
    }
    private func characterTab(_ title: String, image: String, value: String) -> some View {
        Button { selectedTab = value } label: {
            VStack(spacing:2) {
                if !typeSize.isAccessibilitySize { Image(image).resizable().scaledToFit().frame(width:65,height:65).fixedSize().accessibilityHidden(true) }
                Text(title).font(.caption).foregroundStyle(selectedTab == value ? Theme.rose : Theme.teal)
                Capsule().fill(selectedTab == value ? Theme.rose : Color.clear).frame(width:24,height:3)
            }.frame(maxWidth:.infinity,minHeight:44)
        }.buttonStyle(.plain).accessibilityLabel(title).accessibilityAddTraits(selectedTab == value ? [.isSelected] : [])
    }
}

struct TodayView: View {
    @EnvironmentObject var store: DiaryStore
    @Environment(\.dynamicTypeSize) var typeSize
    @Binding var adding: Bool
    @State private var weightOpen = false
    var body: some View {
        let today = Date()
        let total = store.total(on:today)
        ScrollView {
            VStack(alignment:.leading,spacing:24) {
                HStack(alignment:.center) {
                    VStack(alignment:.leading,spacing:12) {
                        Text("好好吃饭，\n慢慢变好。").font(.title).bold()
                        Text("每一餐，都是照顾自己的小事。").foregroundStyle(.secondary)
                    }.frame(maxWidth:.infinity,alignment:.leading)
                    if !typeSize.isAccessibilitySize { Image("NutritionHero").resizable().scaledToFit().frame(width:130).accessibilityHidden(true) }
                }.padding(20).background(Theme.teal.opacity(0.1),in:RoundedRectangle(cornerRadius:16))
                if let profile = store.state.profile, let target = try? Target.calculate(profile) {
                    VStack(alignment:.leading,spacing:16) {
                        HStack { Text("今天的营养").font(.title2).bold(); Spacer(); Text(today,format:.dateTime.month().day()).foregroundStyle(.secondary) }
                        HStack(alignment:.firstTextBaseline,spacing:6) { Text(total.kcal.formatted(.number.precision(.fractionLength(0)))).font(.largeTitle).bold().monospacedDigit(); Text("/ \(Int(target.nutrients.kcal.rounded())) kcal").foregroundStyle(.secondary) }.accessibilityElement(children:.combine)
                        Text(total.kcal > target.nutrients.kcal ? "比目标多约 \(Int((total.kcal-target.nutrients.kcal).rounded())) kcal" : "还可安排约 \(Int((target.nutrients.kcal-total.kcal).rounded())) kcal").foregroundStyle(Theme.rose)
                        MacroRow(name:"蛋白质",value:total.protein,target:target.nutrients.protein,color:Theme.rose)
                        MacroRow(name:"碳水",value:total.carbs,target:target.nutrients.carbs,color:Theme.teal)
                        MacroRow(name:"脂肪",value:total.fat,target:target.nutrients.fat,color:.green)
                        Text(profile.custom ? "手动设定目标 · 可随时调整" : "根据资料估算，可按实际情况调整").font(.footnote).foregroundStyle(.secondary)
                    }.padding(20).background(Color(uiColor:.secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:16))
                } else {
                    Text("先到“我的”建立目标。你也可以直接记录饮食，再使用专业目标。").padding()
                }
                Button { adding = true } label: { Label("记一餐",systemImage:"plus").font(.headline).frame(maxWidth:.infinity,minHeight:44) }.buttonStyle(.borderedProminent)
                Button { weightOpen = true } label: { Label("记体重与照片",systemImage:"scalemass").frame(maxWidth:.infinity,minHeight:44) }.buttonStyle(.bordered)
                if store.mealSaved { HStack { Image("Recovery").resizable().scaledToFit().frame(width:70,height:85).accessibilityHidden(true); Text("这一餐，已经记好啦。").font(.headline) }.accessibilityElement(children:.combine) }
                HStack { Text("今天吃了什么").font(.title2).bold(); Spacer(); Text("\(store.entries(on:today).count) 项").foregroundStyle(.secondary) }
                if store.entries(on:today).isEmpty {
                    VStack(alignment:.leading,spacing:8) { Text("还没记餐呢").font(.headline); Text("试试输入“一碗米饭、一个鸡蛋”。\n不用称重，确认常见份量就可以。").foregroundStyle(.secondary) }.frame(maxWidth:.infinity,alignment:.leading).padding(.vertical,16)
                } else { ForEach(store.entries(on:today)) { EntryRow(entry:$0) } }
            }.padding(20)
        }.background(Theme.paper).navigationTitle("与你食光").sheet(isPresented:$weightOpen) { WeightEditor(initialWeight:store.state.profile?.weight ?? 70) }
    }
}
struct MacroRow: View {
    let name: String; let value: Double; let target: Double; let color: Color
    var body: some View {
        VStack(spacing:6) {
            HStack { Text(name); Spacer(); Text("\(Int(value.rounded())) / \(Int(target.rounded())) g").monospacedDigit().foregroundStyle(.secondary) }
            ProgressView(value:min(value,target),total:max(target,1)).tint(color).accessibilityLabel(name).accessibilityValue("已摄入 \(Int(value)) 克，目标 \(Int(target)) 克")
        }
    }
}
struct EntryRow: View {
    let entry: FoodEntry
    var body: some View {
        HStack(alignment:.top) {
            VStack(alignment:.leading,spacing:5) { Text(entry.name).font(.headline); Text("\(entry.meal) · \(entry.serving)").font(.subheadline).foregroundStyle(.secondary) }
            Spacer(); Text("约 \(Int(entry.nutrients.kcal.rounded())) kcal").monospacedDigit().foregroundStyle(Theme.rose)
        }.padding(.vertical,10)
    }
}
struct RecordsView: View {
    @EnvironmentObject var store: DiaryStore
    @State private var date = Date()
    @State private var editing: FoodEntry?
    @State private var section = "饮食"
    var body: some View {
        VStack(spacing:0) {
        Picker("记录类型",selection:$section) { Text("饮食").tag("饮食"); Text("体重").tag("体重") }.pickerStyle(.segmented).padding(.horizontal)
        if section == "体重" { WeightHistory() } else { List {
            DatePicker("查看日期",selection:$date,displayedComponents:.date)
            if store.entries(on:date).isEmpty { ContentUnavailableView { Label("这一天还没有记录",systemImage:"fork.knife") } description: { Text("记录会保存在这台设备中。") } actions: { Image("Recovery").resizable().scaledToFit().frame(height:110).accessibilityHidden(true) } }
            ForEach(["早餐","午餐","晚餐","加餐"],id:\.self) { meal in
                let entries = store.entries(on:date).filter { $0.meal == meal }
                if !entries.isEmpty { Section(meal) { ForEach(entries) { entry in Button { editing = entry } label: { EntryRow(entry:entry) }.foregroundStyle(.primary).swipeActions { Button("删除",role:.destructive) { store.delete(entry) } } } } }
            }
            if !store.entries(on:date).isEmpty { Section("当天合计") { NutritionSummary(nutrients:store.total(on:date)) } }
        } }
        }.navigationTitle("我的记录").sheet(item:$editing) { EntryDetail(entry:$0) }
    }
}
struct NutritionSummary: View {
    let nutrients: Nutrients
    var body: some View {
        Text("约 \(nutrients.kcal.formatted(.number.precision(.fractionLength(0)))) kcal · 蛋白质 \(nutrients.protein.formatted(.number.precision(.fractionLength(0)))) g · 碳水 \(nutrients.carbs.formatted(.number.precision(.fractionLength(0)))) g · 脂肪 \(nutrients.fat.formatted(.number.precision(.fractionLength(0)))) g").font(.subheadline).monospacedDigit()
    }
}
struct EntryDetail: View {
    @EnvironmentObject var store: DiaryStore
    @Environment(\.dismiss) var dismiss
    let entry: FoodEntry
    @State private var factor = 1.0
    var body: some View {
        NavigationStack { Form {
            Section(entry.name) { Text(entry.serving); NutritionSummary(nutrients:entry.nutrients.scaled(factor)); Slider(value:$factor,in:0.25...3,step:0.25); Text("调整为原记录的 \(factor.formatted()) 倍") }
            Section("估算依据") { Text(entry.basis); Text(entry.source); Text("原记录约 \(Int(entry.grams.rounded())) g；营养值按保存时的快照保留。").font(.footnote) }
            if let image = store.photo(entry.photoName) { Section("记录照片") { Image(uiImage:image).resizable().scaledToFit().accessibilityLabel("这餐的照片") } }
            Section { Button("保存份量修改") { if store.update(entry,factor:factor) { dismiss() } }; Button("删除记录",role:.destructive) { store.delete(entry); dismiss() } }
        }.navigationTitle("查看这一餐").toolbar { ToolbarItem(placement:.cancellationAction) { Button("关闭") { dismiss() } } } }
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: DiaryStore
    @State private var profileOpen = false
    @State private var endpoint = ""
    @State private var clearing = false
    @State private var exportURL: URL?
    var body: some View {
        Form {
            Section("我的目标") { Button("建立或修改资料") { profileOpen = true }; if let p = store.state.profile, let target = try? Target.calculate(p) { NutritionSummary(nutrients:target.nutrients) } }
            Section("照片估算") {
                Text(store.state.endpoint.isEmpty ? "自动识别尚未连接" : "已保存服务地址，实际连接在识别时验证")
                TextField("HTTPS 服务地址",text:$endpoint).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("保存服务地址") { store.save(endpoint:endpoint.trimmingCharacters(in:.whitespacesAndNewlines)) }
                Text("点击照片识别时，只把选定照片发送到该地址。模型密钥由服务端保管；无需读取手机 ChatGPT 或 Codex 的登录凭据。").font(.footnote)
            }
            Section("计算与数据来源") {
                Text("Mifflin–St Jeor：10×kg + 6.25×cm − 5×年龄 + 公式参数。维持热量乘活动系数；减脂 ×0.85，增肌 ×1.10。")
                Text("蛋白质：日常 1.2 g/kg，规律健身 1.6 g/kg；脂肪占能量 30%，其余为碳水。这是温和起始估算。")
                Link("Mifflin 原始论文",destination:URL(string:"https://pubmed.ncbi.nlm.nih.gov/2305711/")!)
                Link("运动者蛋白质参考（ISSN）",destination:URL(string:"https://pmc.ncbi.nlm.nih.gov/articles/PMC5477153/")!)
                Text("食物库为首版参考估算值，混合菜及家庭份量尤其不确定，包装营养标签优先。图片候选也要确认。")
            }
            Section("本机数据") { Text("原生 App 与网页预览各自保存，不自动同步。卸载 App 可能删除数据。"); Button("准备导出 JSON 备份") { exportURL = store.export() }; if let exportURL { ShareLink("分享备份",item:exportURL) }; Button("清除本机资料和记录",role:.destructive) { clearing = true } }
        }.navigationTitle("我的").onAppear { endpoint = store.state.endpoint }
        .sheet(isPresented:$profileOpen) { ProfileEditor(profile:store.state.profile ?? Profile()) }
        .confirmationDialog("清除后不能在 App 内恢复，请先导出备份。",isPresented:$clearing,titleVisibility:.visible) { Button("清除全部本机数据",role:.destructive) { store.clear() }; Button("取消",role:.cancel) {} }
    }
}

struct ProfileEditor: View {
    @EnvironmentObject var store: DiaryStore
    @Environment(\.dismiss) var dismiss
    @State var profile: Profile
    @State private var error: String?
    var body: some View {
        NavigationStack { Form {
            Section { Text("让每一餐，都有一点方向。").font(.title2).bold(); Text("资料只保存在本机。自动目标适用于健康成年人，估算可按实际趋势调整。") }
            Section("目标方式") { Toggle("手动设定",isOn:$profile.custom); Toggle("孕期、哺乳期或需要治疗性饮食",isOn:$profile.restricted); if profile.restricted { Text("这些情况建议由专业人员协助设置目标；记录功能仍可使用。").font(.footnote) } }
            if profile.custom {
                Section("手动每日目标") { NumericField(title:"热量 kcal",value:$profile.customTarget.kcal); NumericField(title:"蛋白质 g",value:$profile.customTarget.protein); NumericField(title:"脂肪 g",value:$profile.customTarget.fat); NumericField(title:"碳水 g",value:$profile.customTarget.carbs); Text("可以先自动估算再微调。体重日记不会自动覆盖这里的目标。").font(.footnote) }
            } else {
                Section("身体资料") { NumericField(title:"身高 cm",value:$profile.height); NumericField(title:"体重 kg",value:$profile.weight); HStack { Text("年龄"); TextField("岁",value:$profile.age,format:.number).keyboardType(.numberPad).multilineTextAlignment(.trailing) }; Picker("公式参数",selection:$profile.formula) { Text("男性公式 +5").tag(5.0); Text("女性公式 −161").tag(-161.0); Text("暂不选择").tag(0.0) }; Text("仅用于传统估算方程，不等同于性别认同。不愿选择时可使用专业自定义目标。").font(.footnote) }
                Section("日常与方向") { Picker("活动量",selection:$profile.activity) { Text("久坐 · 1.2").tag(1.2); Text("轻度 · 1.375").tag(1.375); Text("中度 · 1.55").tag(1.55); Text("高度 · 1.725").tag(1.725) }; Picker("目标",selection:$profile.goal) { Text("减脂").tag(0.85); Text("维持").tag(1.0); Text("增肌").tag(1.10) }; Toggle("规律健身",isOn:$profile.training); Text("活动档位是粗略估计，已包含日常活动，不额外抵扣运动热量。").font(.footnote) }
            }
            if let target = try? Target.calculate(profile) { Section("每天的起始目标") { NutritionSummary(nutrients:target.nutrients); if let ree = target.ree, let tdee = target.tdee { Text("静息估算 \(Int(ree.rounded())) · 维持估算 \(Int(tdee.rounded())) kcal").font(.footnote) } } }
            if let error { Section { Text(error).foregroundStyle(.red) } }
            Section { Button("保存资料和目标") { do { _ = try Target.calculate(profile); if store.save(profile:profile) { dismiss() } } catch { self.error = error.localizedDescription } }; Button("先记录饮食") { dismiss() } }
        }.navigationTitle("我的营养目标").toolbar { ToolbarItem(placement:.cancellationAction) { Button("关闭") { dismiss() } } } }
        .onChange(of:profile.custom) { oldValue, newValue in if !oldValue && newValue { var automatic = profile; automatic.custom = false; if let result = try? Target.calculate(automatic) { profile.customTarget = result.nutrients } } }
    }
}
struct NumericField: View {
    let title: String
    @Binding var value: Double
    var body: some View { HStack { Text(title); TextField(title,value:$value,format:.number).keyboardType(.decimalPad).multilineTextAlignment(.trailing).accessibilityLabel(title) } }
}
