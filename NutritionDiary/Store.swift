import SwiftUI
import Foundation
import UIKit

@MainActor final class DiaryStore: ObservableObject {
    @Published private(set) var state = SavedState()
    @Published var error: String?
    @Published var mealSaved = false
    private let directory: URL
    private let file: URL
    init() {
        directory = FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("NutritionDiary",isDirectory:true)
        file = directory.appendingPathComponent("diary.json")
        do {
            try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
            if FileManager.default.fileExists(atPath:file.path) { state = try JSONDecoder().decode(SavedState.self,from:Data(contentsOf:file)) }
        } catch {
            let backup = directory.appendingPathComponent("diary-unreadable-\(Int(Date().timeIntervalSince1970)).json")
            do {
                if FileManager.default.fileExists(atPath:file.path) { try FileManager.default.copyItem(at:file,to:backup) }
                self.error = "读取失败，原文件已复制保留为 \(backup.lastPathComponent)。可继续新记录。"
            } catch { self.error = "读取与备份失败。为保护原文件，请先在文件中恢复备份后再保存。"; readBlocked = true }
        }
    }
    private var readBlocked = false
    @discardableResult private func commit(_ next: SavedState) -> Bool {
        guard !readBlocked else { error = "原数据无法读取且尚未备份，已停止覆盖保存。"; return false }
        do { try JSONEncoder().encode(next).write(to:file,options:.atomic); state = next; return true }
        catch { self.error = "保存失败，请重试：\(error.localizedDescription)"; return false }
    }
    @discardableResult func save(profile: Profile) -> Bool { var next = state; next.profile = profile; return commit(next) }
    func save(endpoint: String) { var next = state; next.endpoint = endpoint; commit(next) }
    @discardableResult func add(_ drafts: [DraftItem], date: Date, meal: String, photo: Data?) -> Bool {
        guard !drafts.isEmpty, drafts.count <= 100, ["早餐","午餐","晚餐","加餐"].contains(meal), date.timeIntervalSince1970.isFinite,
              drafts.allSatisfy({ $0.grams.isFinite && $0.grams > 0 && $0.grams <= 3000 && $0.nutrients.isValid && $0.eaten > 0 && $0.eaten <= 1 }),
              photo == nil || photo!.count <= 12_000_000 else { error = "记录包含无效份量、营养值或过大的照片，请核对。"; return false }
        var photoName: String?
        do {
            if let photo { let name = UUID().uuidString+".jpg"; try photo.write(to:directory.appendingPathComponent(name),options:.atomic); photoName = name }
        } catch { self.error = "照片保存失败：\(error.localizedDescription)"; return false }
        var next = state
        next.entries += drafts.map { item in FoodEntry(date:date,meal:meal,name:item.food.name,grams:item.grams,nutrients:item.nutrients,serving:"\(item.portions.formatted())\(item.food.unit) · \(item.size == 0.75 ? "小份" : item.size == 1.5 ? "大份" : "正常") · 吃了\(Int(item.eaten*100))%",source:item.food.source,basis:item.basis,photoName:photoName) }
        if commit(next) { mealSaved = true; return true }
        if let photoName { try? FileManager.default.removeItem(at:directory.appendingPathComponent(photoName)) }
        return false
    }
    func delete(_ entry: FoodEntry) {
        var next = state; next.entries.removeAll { $0.id == entry.id }
        if commit(next), let photo = entry.photoName, !next.entries.contains(where:{$0.photoName == photo}) { try? FileManager.default.removeItem(at:directory.appendingPathComponent(photo)) }
    }
    @discardableResult func saveWeight(existing: WeightLog?, date: Date, weight: Double, photo: Data?, removePhoto: Bool) -> Bool {
        guard weight.isFinite, (20...350).contains(weight), date.timeIntervalSince1970.isFinite, photo == nil || photo!.count <= 12_000_000 else { error = "请填写 20–350 kg 范围的有效体重，并使用 12 MB 以下照片。"; return false }
        var log = existing ?? WeightLog(date:date,weight:weight)
        let oldPhoto = log.photoName
        var newPhoto: String?
        do { if let photo { let name = UUID().uuidString+".jpg"; try photo.write(to:directory.appendingPathComponent(name),options:.atomic); newPhoto = name } }
        catch { self.error = "体重照片保存失败：\(error.localizedDescription)"; return false }
        log.date = date; log.weight = weight
        if let newPhoto { log.photoName = newPhoto } else if removePhoto { log.photoName = nil }
        var next = state
        if let index = next.weightLogs.firstIndex(where:{$0.id == log.id}) { next.weightLogs[index] = log } else { next.weightLogs.append(log) }
        if commit(next) { if let oldPhoto, oldPhoto != log.photoName { try? FileManager.default.removeItem(at:directory.appendingPathComponent(oldPhoto)) }; return true }
        if let newPhoto { try? FileManager.default.removeItem(at:directory.appendingPathComponent(newPhoto)) }; return false
    }
    func deleteWeight(_ log: WeightLog) {
        var next = state; next.weightLogs.removeAll { $0.id == log.id }
        if commit(next), let photo = log.photoName { try? FileManager.default.removeItem(at:directory.appendingPathComponent(photo)) }
    }
    @discardableResult func update(_ entry: FoodEntry, factor: Double) -> Bool {
        guard factor > 0, factor.isFinite, factor <= 10, let index = state.entries.firstIndex(where:{$0.id == entry.id}) else { return false }
        var next = state
        guard entry.grams*factor <= 3000, entry.nutrients.scaled(factor).isValid else { error = "调整后的份量须不超过 3000 克。"; return false }
        next.entries[index].grams *= factor
        next.entries[index].nutrients = entry.nutrients.scaled(factor)
        next.entries[index].serving = "已调整为原记录的 \(factor.formatted()) 倍"
        return commit(next)
    }
    func photo(_ name: String?) -> UIImage? { guard let name, !name.contains("/"), !name.contains("..") else { return nil }; return UIImage(contentsOfFile:directory.appendingPathComponent(name).path) }
    func entries(on date: Date) -> [FoodEntry] { state.entries.filter { Calendar.current.isDate($0.date,inSameDayAs:date) } }
    func total(on date: Date) -> Nutrients { entries(on:date).reduce(Nutrients()) { $0+$1.nutrients } }
    func clear() {
        let photoNames = Set(state.entries.compactMap(\.photoName)+state.weightLogs.compactMap(\.photoName))
        if commit(SavedState()) { for name in photoNames { try? FileManager.default.removeItem(at:directory.appendingPathComponent(name)) } }
    }
    func export() -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("与你食光-备份.json")
        do { try JSONEncoder().encode(state).write(to:url,options:.atomic); return url }
        catch { self.error = "导出失败：\(error.localizedDescription)"; return nil }
    }
}

struct VisionResponse: Decodable {
    struct Item: Decodable { let foodId: String; let grams: Double; let confidence: Double? }
    let items: [Item]
    let note: String?
}
enum PhotoService {
    static func estimate(data: Data, endpoint: String) async throws -> ([DraftItem], String) {
        guard data.count <= 5*1024*1024 else { throw TargetError.invalid("AI 估算照片须在 5 MB 以内，请选择较小图片。") }
        return try await request(input:["imageBase64":data.base64EncodedString(),"mimeType":"image/jpeg"],endpoint:endpoint)
    }
    static func estimate(text: String, endpoint: String) async throws -> ([DraftItem], String) {
        let value = text.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !value.isEmpty, value.utf16.count <= 4000 else { throw TargetError.invalid("请输入 1–4000 字的餐食描述。") }
        return try await request(input:["text":value],endpoint:endpoint)
    }
    private static func request(input: [String:String], endpoint: String) async throws -> ([DraftItem], String) {
        guard let url = URL(string:endpoint), url.scheme == "https", url.host != nil, url.user == nil, url.password == nil else { throw TargetError.invalid("请先在“我的”配置 HTTPS 识别服务地址。模型密钥只放服务端。") }
        var request = URLRequest(url:url,timeoutInterval:35)
        request.httpMethod = "POST"; request.setValue("application/json",forHTTPHeaderField:"Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject:input)
        let (body,response) = try await URLSession.shared.data(for:request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), body.count < 1_000_000 else { throw TargetError.invalid("识别服务返回错误，请手动添加或重试。") }
        let decoded = try JSONDecoder().decode(VisionResponse.self,from:body)
        guard decoded.items.count <= 30, (decoded.note?.utf16.count ?? 0) <= 2000 else { throw TargetError.invalid("候选数量或说明过长，请手动继续。") }
        var drafts: [DraftItem] = []
        for item in decoded.items {
            guard let food = FoodBook.foods.first(where:{$0.id == item.foodId}), item.grams.isFinite, item.grams > 0, item.grams <= 3000, let confidence = item.confidence, confidence.isFinite, (0...1).contains(confidence) else { throw TargetError.invalid("服务返回未知食物或无效份量，请手动核对。") }
            var draft = DraftItem(food:food); draft.portions = item.grams/food.portionGrams; draft.basis = "AI 服务候选，需确认隐藏油、酱汁及份量"; drafts.append(draft)
        }
        return (drafts, decoded.note ?? "请核对食物和份量，照片无法可靠看出隐藏油与调料。")
    }
}
