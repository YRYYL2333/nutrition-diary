import SwiftUI
import PhotosUI
import AVFoundation

struct MealEditor: View {
    @EnvironmentObject var store: DiaryStore
    @Environment(\.dismiss) var dismiss
    @State private var mode = "一句话"
    @State private var text = ""
    @State private var date = Date()
    @State private var meal = "午餐"
    @State private var drafts: [DraftItem] = []
    @State private var unresolved: [String] = []
    @State private var acknowledged = false
    @State private var photoItem: PhotosPickerItem?
    @State private var photo: Data?
    @State private var cameraOpen = false
    @State private var message = ""
    @State private var working = false
    @State private var saving = false
    @State private var manualName = ""
    @State private var manual = Nutrients()
    var body: some View {
        NavigationStack { Form {
            Section { HStack { Text("确认一下，就记好啦。").font(.headline); Spacer(); Image("MealReview").resizable().scaledToFit().frame(width:70,height:85).accessibilityHidden(true) }; Picker("添加方式",selection:$mode) { ForEach(["一句话","常用食物","照片","手动"],id:\.self) { Text($0) } }.pickerStyle(.segmented); Picker("餐次",selection:$meal) { ForEach(["早餐","午餐","晚餐","加餐"],id:\.self) { Text($0) } }; DatePicker("日期",selection:$date,displayedComponents:.date) }
            if mode == "一句话" {
                Section("不用称重，也能记下来") { TextField("一碗米饭、半盘番茄炒蛋、一杯牛奶",text:$text,axis:.vertical).lineLimit(3...6); Button("匹配食物和份量") { let parsed = MealParser.parse(text); drafts = parsed.items; unresolved = parsed.unresolved; acknowledged = false; message = drafts.isEmpty ? "没有匹配到，请试试常用食物或手动填写。" : "按常见家庭份量估算，请确认下方候选。" }; Text("支持碗、盘、个、杯、份、根；也支持“米饭150克 鸡蛋2个”。油和调料请另行核对。").font(.footnote).foregroundStyle(.secondary) }
                Section("AI 描述估算") {
                    Text(store.state.endpoint.isEmpty ? "尚未连接 AI，可使用上方本地匹配。" : "点击按钮才会将这段餐食描述发送至：\(store.state.endpoint)").font(.footnote)
                    Button(working ? "正在请求候选…" : "发送描述并用 AI 估算") { Task { await estimateText() } }.disabled(working || text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || store.state.endpoint.isEmpty)
                }
            } else if mode == "常用食物" {
                Section("点一下加入审核") { ForEach(FoodBook.foods) { food in Button { drafts.append(DraftItem(food:food)) } label: { HStack { VStack(alignment:.leading) { Text(food.name); Text("1\(food.unit) · 约 \(Int(food.per100.kcal*food.portionGrams/100)) kcal").font(.footnote).foregroundStyle(.secondary) }; Spacer(); Image(systemName:"plus.circle") } } } }
                if !store.state.entries.isEmpty { Section("最近记录 · 可调整后复用") { ForEach(Array(store.state.entries.suffix(5).reversed())) { entry in Button(entry.name+" · "+entry.serving) { let food = Food(id:"reuse-"+entry.id.uuidString,name:entry.name,aliases:[],unit:"份",portionGrams:entry.grams,per100:entry.nutrients.scaled(100/entry.grams),source:entry.source); var item = DraftItem(food:food); item.basis = "复用历史营养快照"; drafts.append(item) } } } }
            } else if mode == "照片" {
                Section("拍照或选一张餐食照片") {
                    Button { Task { let allowed = await AVCaptureDevice.requestAccess(for:.video); if allowed && UIImagePickerController.isSourceTypeAvailable(.camera) { cameraOpen = true } else { message = "相机不可用或未授权，可在系统设置允许相机，或从相册选择。" } } } label: { Label("打开相机",systemImage:"camera") }
                    PhotosPicker(selection:$photoItem,matching:.images) { Label("从相册选择",systemImage:"photo") }
                    if let photo, let image = UIImage(data:photo) { Image(uiImage:image).resizable().scaledToFit().frame(maxHeight:220).accessibilityLabel("已选择的餐食照片"); Button("移除照片",role:.destructive) { self.photo = nil } }
                    Text(store.state.endpoint.isEmpty ? "照片已添加时可随记录保存；自动识别尚未连接。先描述食物或从食物库添加。" : "只有点击下方按钮，才会将这张照片发送到：\(store.state.endpoint)").font(.footnote)
                    Button(working ? "正在请求候选…" : "发送照片并估算") { Task { await estimate() } }.disabled(photo == nil || working || store.state.endpoint.isEmpty)
                    Text("AI 候选需核对小/正常/大份与吃下比例，不能从照片准确看出隐藏油、糖和酱汁。").font(.footnote).foregroundStyle(.secondary)
                }
            } else {
                Section("按包装标签或自己的资料添加") { TextField("食物名称",text:$manualName); Text("以下填写这一份的营养值，不是每 100g。").font(.footnote); NumericField(title:"热量 kcal",value:$manual.kcal); NumericField(title:"蛋白质 g",value:$manual.protein); NumericField(title:"脂肪 g",value:$manual.fat); NumericField(title:"碳水 g",value:$manual.carbs); Button("加入审核") { guard !manualName.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty, manual.isValid, manual.kcal <= 10000, manual.protein <= 600, manual.fat <= 600, manual.carbs <= 1500 else { message = "请填写名称和有效的这一份营养值。"; return }; let food = Food(id:UUID().uuidString,name:manualName,aliases:[],unit:"份",portionGrams:100,per100:manual,source:"用户手动填写，请以包装营养表或专业资料为准"); var item = DraftItem(food:food); item.basis = "手动营养记录；内部份量基准不代表实际称重"; drafts.append(item); manualName = ""; manual = Nutrients() } }
            }
            if !message.isEmpty { Section { Text(message).font(.subheadline).foregroundStyle(.secondary) } }
            if !unresolved.isEmpty { Section("还有内容未匹配") { ForEach(unresolved,id:\.self) { Text($0).foregroundStyle(.red) }; Text("可用常用食物或手动补齐，再确认以下选项。").font(.footnote); Toggle("已核对，只保存下方确认项目",isOn:$acknowledged) } }
            if !drafts.isEmpty {
                Section("确认份量再保存") { Text("无需称重。默认份量只是估计，营养值均为“约”。").font(.footnote); ForEach($drafts) { $draft in DraftReview(item:$draft); Button("移除 \(draft.food.name)",role:.destructive) { drafts.removeAll { $0.id == draft.id } } }; NutritionSummary(nutrients:drafts.reduce(Nutrients()) { $0+$1.nutrients }) }
            }
        }.navigationTitle("记一餐").toolbar { ToolbarItem(placement:.cancellationAction) { Button("取消") { dismiss() } }; ToolbarItem(placement:.confirmationAction) { Button("保存") { save() }.disabled(drafts.isEmpty || saving || working || (!unresolved.isEmpty && !acknowledged)) } } }
        .onChange(of:photoItem) { _, item in Task { do { if let data = try await item?.loadTransferable(type:Data.self), let image = UIImage(data:data), let jpeg = image.jpegData(compressionQuality:0.8) { guard jpeg.count <= 12_000_000 else { message = "照片超过 12 MB，请换一张较小的照片。"; return }; photo = jpeg; message = store.state.endpoint.isEmpty ? "照片已添加，自动识别尚未连接。" : "照片已添加，点击发送才会上传。" } } catch { message = "照片读取失败，请重新选择。" } } }
        .sheet(isPresented:$cameraOpen) { CameraPicker { image in photo = image.jpegData(compressionQuality:0.8); message = "照片已添加，尚未上传。" } }
    }
    private func save() {
        guard !saving, !drafts.isEmpty else { return }
        guard drafts.allSatisfy({ $0.grams.isFinite && $0.grams > 0 && $0.grams <= 3000 && $0.nutrients.isValid && $0.portions > 0 && $0.eaten > 0 && $0.eaten <= 1 }) else { message = "有一项份量无效，请核对后保存。"; return }
        saving = true
        if store.add(drafts,date:date,meal:meal,photo:photo) { dismiss() } else { saving = false }
    }
    private func estimate() async {
        guard let photo else { return }; working = true; defer { working = false }
        do { let (items,note) = try await PhotoService.estimate(data:photo,endpoint:store.state.endpoint); drafts.append(contentsOf:items); message = note }
        catch { message = "\(error.localizedDescription) 输入和照片仍保留，可继续手动添加。" }
    }
    private func estimateText() async {
        working = true; defer { working = false }
        do { let (items,note) = try await PhotoService.estimate(text:text,endpoint:store.state.endpoint); drafts.append(contentsOf:items); message = note }
        catch { message = "\(error.localizedDescription) 描述仍保留，可继续本地匹配。" }
    }
}

struct DraftReview: View {
    @Binding var item: DraftItem
    @State private var advanced = false
    var body: some View {
        VStack(alignment:.leading,spacing:10) {
            Text(item.food.name).font(.headline)
            Stepper("\(item.portions.formatted())\(item.food.unit)",value:$item.portions,in:0.25...10,step:0.25).disabled(item.exactGrams != nil)
            Picker("份量",selection:$item.size) { Text("小份").tag(0.75); Text("正常").tag(1.0); Text("大份").tag(1.5) }.pickerStyle(.segmented).disabled(item.exactGrams != nil)
            Picker("吃了几成",selection:$item.eaten) { ForEach(1...10,id:\.self) { value in Text("\(value)成").tag(Double(value)/10) } }
            NutritionSummary(nutrients:item.nutrients)
            DisclosureGroup("高级：克数与来源",isExpanded:$advanced) {
                Toggle("使用已知克数",isOn:Binding(get:{item.exactGrams != nil},set:{item.exactGrams = $0 ? item.food.portionGrams*item.portions*item.size : nil}))
                if item.exactGrams != nil { NumericField(title:"食用前总克数",value:Binding(get:{item.exactGrams ?? 0},set:{item.exactGrams = $0})) }
                Text("当前食用量中心估值约 \(item.grams.formatted(.number.precision(.fractionLength(0)))) g。普通家庭份量可上下浮动约 25%，这不是统计置信区间。\n\(item.food.source)").font(.footnote).foregroundStyle(.secondary)
            }
        }.padding(.vertical,8)
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss
    var completion: (UIImage) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context:Context) -> UIImagePickerController { let controller = UIImagePickerController(); controller.sourceType = .camera; controller.cameraCaptureMode = .photo; controller.delegate = context.coordinator; return controller }
    func updateUIViewController(_ uiViewController:UIImagePickerController,context:Context) {}
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent:CameraPicker) { self.parent = parent }
        func imagePickerControllerDidCancel(_ picker:UIImagePickerController) { parent.dismiss() }
        func imagePickerController(_ picker:UIImagePickerController,didFinishPickingMediaWithInfo info:[UIImagePickerController.InfoKey:Any]) { if let image = info[.originalImage] as? UIImage { parent.completion(image) }; parent.dismiss() }
    }
}
