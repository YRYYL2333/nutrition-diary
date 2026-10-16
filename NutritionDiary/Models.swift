import Foundation

struct Nutrients: Codable, Equatable {
    var kcal: Double = 0
    var protein: Double = 0
    var fat: Double = 0
    var carbs: Double = 0
    static func + (a: Self, b: Self) -> Self { .init(kcal: a.kcal+b.kcal, protein: a.protein+b.protein, fat: a.fat+b.fat, carbs: a.carbs+b.carbs) }
    func scaled(_ multiplier: Double) -> Self { .init(kcal: kcal*multiplier, protein: protein*multiplier, fat: fat*multiplier, carbs: carbs*multiplier) }
    var isValid: Bool { [kcal, protein, fat, carbs].allSatisfy { $0.isFinite && $0 >= 0 } && kcal > 0 }
}

struct Profile: Codable {
    var height: Double = 175
    var weight: Double = 70
    var age: Int = 30
    var formula: Double = 5
    var activity: Double = 1.55
    var goal: Double = 0.85
    var training = true
    var restricted = false
    var custom = false
    var customTarget = Nutrients(kcal: 2100, protein: 110, fat: 70, carbs: 257.5)
}

enum TargetError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
}
struct Target {
    let nutrients: Nutrients
    let ree: Double?
    let tdee: Double?
    static func calculate(_ p: Profile) throws -> Self {
        if p.custom {
            guard p.customTarget.isValid, p.customTarget.kcal <= 10000,
                  p.customTarget.protein <= 600, p.customTarget.fat <= 600, p.customTarget.carbs <= 1500 else {
                throw TargetError.invalid("请检查手动目标，热量须大于 0，营养值不能为负。")
            }
            let energy = p.customTarget.protein*4+p.customTarget.fat*9+p.customTarget.carbs*4
            guard abs(energy-p.customTarget.kcal) <= p.customTarget.kcal*0.15 else { throw TargetError.invalid("三大营养素对应能量与总热量相差超过 15%，请核对手动目标。") }
            return .init(nutrients: p.customTarget, ree: nil, tdee: nil)
        }
        guard !p.restricted else { throw TargetError.invalid("孕期、哺乳期或治疗性饮食请使用专业目标；仍可记录饮食。") }
        guard p.height.isFinite, p.weight.isFinite, (120...230).contains(p.height), (35...250).contains(p.weight), (18...100).contains(p.age),
              [5.0,-161.0].contains(p.formula), [1.2,1.375,1.55,1.725].contains(p.activity), [0.85,1,1.10].contains(p.goal) else {
            throw TargetError.invalid("自动估算适用于 18–100 岁；请填写 120–230 cm、35–250 kg 范围内的资料并选择公式参数。")
        }
        guard !(p.goal < 1 && p.weight / pow(p.height/100,2) < 18.5) else { throw TargetError.invalid("当前 BMI 低于 18.5，停止自动减脂建议。可改为维持或使用专业目标。") }
        let ree = 10*p.weight+6.25*p.height-5*Double(p.age)+p.formula
        let tdee = ree*p.activity
        let energy = tdee*p.goal
        let protein = p.weight*(p.training ? 1.6 : 1.2)
        let fat = energy*0.3/9
        let carbs = (energy-protein*4-fat*9)/4
        let n = Nutrients(kcal: energy, protein: protein, fat: fat, carbs: carbs)
        guard n.isValid, energy >= 1200, protein*4/energy <= 0.35, carbs*4/energy >= 0.45 else {
            throw TargetError.invalid("当前参数使热量或营养比例需要个别调整，已停止自动推荐。请复核活动量，或使用专业人员给定的目标。1200 kcal 只是产品拦截阈值。")
        }
        return .init(nutrients: n, ree: ree, tdee: tdee)
    }
}

struct Food: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let aliases: [String]
    let unit: String
    let portionGrams: Double
    let per100: Nutrients
    let source: String
    static func == (lhs: Food, rhs: Food) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
enum FoodBook {
    static let source = "首版参考估算；参考 USDA 常见食物值，未接实时数据库。请以包装营养表和实际做法为准。"
    static let foods: [Food] = [
        .init(id:"rice",name:"米饭（熟）",aliases:["米饭","白饭","饭"],unit:"碗",portionGrams:150,per100:.init(kcal:130,protein:2.7,fat:0.3,carbs:28.2),source:source),
        .init(id:"chicken",name:"鸡胸肉（熟）",aliases:["鸡胸肉","鸡胸"],unit:"份",portionGrams:120,per100:.init(kcal:165,protein:31,fat:3.6,carbs:0),source:source),
        .init(id:"egg",name:"鸡蛋",aliases:["鸡蛋","水煮蛋","煮蛋"],unit:"个",portionGrams:50,per100:.init(kcal:155,protein:12.6,fat:10.6,carbs:1.1),source:source),
        .init(id:"milk",name:"全脂牛奶",aliases:["牛奶","全脂奶"],unit:"杯",portionGrams:250,per100:.init(kcal:61,protein:3.2,fat:3.3,carbs:4.8),source:source),
        .init(id:"broccoli",name:"西兰花（熟）",aliases:["西兰花"],unit:"份",portionGrams:100,per100:.init(kcal:35,protein:2.4,fat:0.4,carbs:7.2),source:source),
        .init(id:"banana",name:"香蕉",aliases:["香蕉"],unit:"根",portionGrams:100,per100:.init(kcal:89,protein:1.1,fat:0.3,carbs:22.8),source:source),
        .init(id:"oats",name:"燕麦片（干）",aliases:["燕麦片","燕麦"],unit:"份",portionGrams:40,per100:.init(kcal:389,protein:16.9,fat:6.9,carbs:66.3),source:source),
        .init(id:"tofu",name:"豆腐",aliases:["豆腐"],unit:"份",portionGrams:100,per100:.init(kcal:76,protein:8.1,fat:4.8,carbs:1.9),source:source),
        .init(id:"tomatoegg",name:"番茄炒蛋",aliases:["番茄炒蛋","西红柿炒鸡蛋","西红柿炒蛋"],unit:"盘",portionGrams:200,per100:.init(kcal:100,protein:5.5,fat:7,carbs:5),source:"人工混合菜粗估；用油和配料会显著改变结果。"),
        .init(id:"apple",name:"苹果",aliases:["苹果"],unit:"个",portionGrams:180,per100:.init(kcal:52,protein:0.3,fat:0.2,carbs:13.8),source:source)
    ]
}

struct DraftItem: Identifiable {
    var id = UUID()
    var food: Food
    var portions: Double = 1
    var size: Double = 1
    var eaten: Double = 1
    var exactGrams: Double? = nil
    var basis = "按常见家庭份量估算"
    var grams: Double { (exactGrams ?? food.portionGrams*portions*size)*eaten }
    var nutrients: Nutrients { food.per100.scaled(grams/100) }
}
struct ParseResult { var items: [DraftItem]; var unresolved: [String] }
enum MealParser {
    static func parse(_ text: String) -> ParseResult {
        // shortcut: a small offline dictionary; unknown text stays visible for manual review.
        let aliases = FoodBook.foods.flatMap(\.aliases).sorted { $0.count > $1.count }.map(NSRegularExpression.escapedPattern(for:)).joined(separator:"|")
        guard let matcher = try? NSRegularExpression(pattern:aliases) else { return .init(items:[],unresolved:[text]) }
        let quantity = "(半|一|二|两|三|四|五|六|七|八|九|十|[0-9]+(?:\\.[0-9]+)?)"
        let numbers: [String:Double] = ["半":0.5,"一":1,"二":2,"两":2,"三":3,"四":4,"五":5,"六":6,"七":7,"八":8,"九":9,"十":10]
        var result = ParseResult(items:[],unresolved:[])
        func match(_ value: String, _ pattern: String) -> (NSRange,String,String)? {
            let ns = value as NSString
            guard let re = try? NSRegularExpression(pattern:pattern,options:.caseInsensitive), let m = re.firstMatch(in:value,range:NSRange(location:0,length:ns.length)) else { return nil }
            return (m.range,ns.substring(with:m.range(at:1)),ns.substring(with:m.range(at:2)))
        }
        for raw in text.components(separatedBy:CharacterSet(charactersIn:"，,、；;\n和与")) {
            let part = raw as NSString
            let matches = matcher.matches(in:raw,range:NSRange(location:0,length:part.length))
            var consumed = 0
            for (index,m) in matches.enumerated() {
                guard let food = FoodBook.foods.first(where:{$0.aliases.contains(part.substring(with:m.range))}) else { continue }
                let next = index+1 < matches.count ? matches[index+1] : nil
                let prefix = part.substring(with:NSRange(location:consumed,length:m.range.location-consumed))
                let suffixStart = NSMaxRange(m.range)
                let suffix = part.substring(with:NSRange(location:suffixStart,length:(next?.range.location ?? part.length)-suffixStart))
                let unit = NSRegularExpression.escapedPattern(for:food.unit)
                let before = match(prefix,quantity+"\\s*("+unit+"|克|g)\\s*$")
                var after = match(suffix,"^\\s*"+quantity+"\\s*("+unit+"|克|g)")
                if let next, let following = FoodBook.foods.first(where:{$0.aliases.contains(part.substring(with:next.range))}), let value = after, value.2 == following.unit {
                    let nextHasSuffix = match(part.substring(from:NSMaxRange(next.range)),"^\\s*"+quantity+"\\s*("+following.unit+"|克|g)") != nil
                    if before != nil || (!nextHasSuffix && Double(value.1) == nil) { after = nil }
                }
                let residue = (prefix as NSString).substring(to:before?.0.location ?? (prefix as NSString).length).trimmingCharacters(in:.whitespacesAndNewlines)
                if !residue.isEmpty { result.unresolved.append(residue) }
                if before != nil && after != nil { result.unresolved.append("同一食物前后都有份量，请保留一种写法") }
                var draft = DraftItem(food:food)
                if let value = after ?? before {
                    let amount = numbers[value.1] ?? Double(value.1) ?? 0
                    if ["克","g"].contains(value.2.lowercased()) { draft.exactGrams = amount; draft.basis = "按输入克数估算" }
                    else { draft.portions = amount }
                }
                if draft.grams > 0 && draft.grams <= 3000 { result.items.append(draft) }
                else { result.unresolved.append(food.name+"：份量须大于0且不超过3000克") }
                consumed = suffixStart + (after.map { NSMaxRange($0.0) } ?? 0)
            }
            let remaining = part.substring(from:consumed).trimmingCharacters(in:.whitespacesAndNewlines)
            if !remaining.isEmpty { result.unresolved.append(remaining) }
        }
        return result
    }
}

struct FoodEntry: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var meal: String
    var name: String
    var grams: Double
    var nutrients: Nutrients
    var serving: String
    var source: String
    var basis: String
    var photoName: String?
}

struct WeightLog: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var weight: Double
    var photoName: String?
}
struct SavedState: Codable {
    var profile: Profile?
    var entries: [FoodEntry] = []
    var endpoint = ""
    var weightLogs: [WeightLog] = []
    init(profile: Profile? = nil, entries: [FoodEntry] = [], endpoint: String = "", weightLogs: [WeightLog] = []) { self.profile = profile; self.entries = entries; self.endpoint = endpoint; self.weightLogs = weightLogs }
    enum CodingKeys: String, CodingKey { case profile, entries, endpoint, weightLogs }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy:CodingKeys.self)
        profile = try values.decodeIfPresent(Profile.self,forKey:.profile)
        entries = try values.decodeIfPresent([FoodEntry].self,forKey:.entries) ?? []
        endpoint = try values.decodeIfPresent(String.self,forKey:.endpoint) ?? ""
        weightLogs = try values.decodeIfPresent([WeightLog].self,forKey:.weightLogs) ?? []
    }
}
