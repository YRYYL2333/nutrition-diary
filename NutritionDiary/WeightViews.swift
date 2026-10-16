import SwiftUI
import PhotosUI
import Charts
import AVFoundation

struct WeightHistory: View {
    @EnvironmentObject var store: DiaryStore
    @State private var adding = false
    @State private var editing: WeightLog?
    var body: some View {
        List {
            Section { Button { adding = true } label: { Label("记体重与照片",systemImage:"plus") }; Text("每次变化都值得温柔对待。记录不会自动改动营养目标中的体重。").font(.footnote).foregroundStyle(.secondary) }
            if store.state.weightLogs.isEmpty {
                Section { HStack { Image("Stretching").resizable().scaledToFit().frame(width:100,height:130).accessibilityHidden(true); VStack(alignment:.leading,spacing:8) { Text("记录自己的节奏").font(.headline); Text("先留下今天的体重。照片可选，仅保存在本机。") } } }
            } else {
                Section("体重变化 · kg") {
                    Chart(store.state.weightLogs.sorted { $0.date < $1.date }) { log in
                        LineMark(x:.value("日期",log.date),y:.value("体重",log.weight)).foregroundStyle(Theme.teal)
                        PointMark(x:.value("日期",log.date),y:.value("体重",log.weight)).foregroundStyle(Theme.rose)
                    }.chartYScale(domain:.automatic(includesZero:false)).frame(height:200).accessibilityLabel("体重随日期变化，下方列表提供每条精确记录")
                    Text("单日波动可能来自水分与测量条件，关注较长时间的趋势。").font(.footnote).foregroundStyle(.secondary)
                }
                Section("按日期回看") {
                    ForEach(store.state.weightLogs.sorted { $0.date > $1.date }) { log in
                        Button { editing = log } label: {
                            HStack { if let image = store.photo(log.photoName) { Image(uiImage:image).resizable().scaledToFill().frame(width:52,height:64).clipped().accessibilityLabel("本次体重照片") }; VStack(alignment:.leading,spacing:4) { Text("\(log.weight.formatted(.number.precision(.fractionLength(1)))) kg").font(.headline).monospacedDigit(); Text(log.date,format:.dateTime.year().month().day().hour().minute()).font(.subheadline).foregroundStyle(.secondary) }; Spacer(); Image(systemName:"chevron.right").font(.caption) }
                        }.foregroundStyle(.primary).swipeActions { Button("删除",role:.destructive) { store.deleteWeight(log) } }
                    }
                }
            }
        }.sheet(isPresented:$adding) { WeightEditor(initialWeight:store.state.profile?.weight ?? 70) }.sheet(item:$editing) { log in WeightEditor(existing:log,initialWeight:log.weight) }
    }
}

struct WeightEditor: View {
    @EnvironmentObject var store: DiaryStore
    @Environment(\.dismiss) var dismiss
    let existing: WeightLog?
    @State private var date: Date
    @State private var weight: Double
    @State private var selection: PhotosPickerItem?
    @State private var photo: Data?
    @State private var removePhoto = false
    @State private var cameraOpen = false
    @State private var message = ""
    @State private var saving = false
    init(existing: WeightLog? = nil, initialWeight: Double) { self.existing = existing; _date = State(initialValue:existing?.date ?? Date()); _weight = State(initialValue:existing?.weight ?? initialWeight) }
    var body: some View {
        NavigationStack { Form {
            Section { HStack { VStack(alignment:.leading,spacing:6) { Text("一点一点，看见变化。").font(.headline); Text("体重和照片默认仅保存在本机，不会送去 AI。").font(.footnote).foregroundStyle(.secondary) }; Image("Stretching").resizable().scaledToFit().frame(width:80,height:100).accessibilityHidden(true) } }
            Section("这一次的记录") { DatePicker("日期与时间",selection:$date); NumericField(title:"体重 kg",value:$weight); Text("同日可以记录多次，以时间区分；不会覆盖另一条记录或自动改变营养目标。").font(.footnote).foregroundStyle(.secondary) }
            Section("照片 · 可选") {
                PhotosPicker(selection:$selection,matching:.images) { Label("选择变化照片",systemImage:"photo") }
                Button { Task { let allowed = await AVCaptureDevice.requestAccess(for:.video); if allowed && UIImagePickerController.isSourceTypeAvailable(.camera) { cameraOpen = true } else { message = "相机不可用或未授权，请在系统设置允许相机，或从照片选择。" } } } label: { Label("拍一张照片",systemImage:"camera") }
                if let image = previewImage { Image(uiImage:image).resizable().scaledToFit().frame(maxHeight:260).accessibilityLabel("本次体重变化照片"); Button("移除照片",role:.destructive) { photo = nil; removePhoto = true } }
            }
            if !message.isEmpty { Section { Text(message).foregroundStyle(.red) } }
            if let existing { Section { Button("删除这条体重记录",role:.destructive) { store.deleteWeight(existing); dismiss() } } }
        }.navigationTitle(existing == nil ? "记体重" : "编辑体重").toolbar { ToolbarItem(placement:.cancellationAction) { Button("取消") { dismiss() } }; ToolbarItem(placement:.confirmationAction) { Button("保存") { guard !saving else { return }; saving = true; if store.saveWeight(existing:existing,date:date,weight:weight,photo:photo,removePhoto:removePhoto) { dismiss() } else { saving = false; message = store.error ?? "保存失败，请重试。" } }.disabled(saving) } } }
        .onChange(of:selection) { _, value in Task { do { if let data = try await value?.loadTransferable(type:Data.self), let image = UIImage(data:data), let jpeg = image.jpegData(compressionQuality:0.8) { guard jpeg.count <= 12_000_000 else { message = "照片过大，请选择 12 MB 以下图片。"; return }; photo = jpeg; removePhoto = false } } catch { message = "无法读取照片，请重新选择。" } } }
        .sheet(isPresented:$cameraOpen) { CameraPicker { image in photo = image.jpegData(compressionQuality:0.8); removePhoto = false } }
    }
    private var previewImage: UIImage? { if let photo { return UIImage(data:photo) }; return removePhoto ? nil : store.photo(existing?.photoName) }
}
