import Foundation

// MARK: - Basic types

enum PetStage: String, Codable, Hashable {
    case pichu
    case pikachu

    var displayName: String {
        switch self {
        case .pichu: return "피츄"
        case .pikachu: return "피카츄"
        }
    }
}

enum PetMood: String, Codable, Hashable {
    case sleeping, sick, hungry, dirty, sleepy, sad, happy, normal

    var emoji: String {
        switch self {
        case .sleeping: return "💤"
        case .sick: return "🤒"
        case .hungry: return "🍎"
        case .dirty: return "💩"
        case .sleepy: return "🥱"
        case .sad: return "😢"
        case .happy: return "⚡"
        case .normal: return "🙂"
        }
    }

    var label: String {
        switch self {
        case .sleeping: return "쿨쿨 자는 중"
        case .sick: return "아파요"
        case .hungry: return "배고파요"
        case .dirty: return "치워주세요"
        case .sleepy: return "졸려요"
        case .sad: return "심심해요"
        case .happy: return "기분 최고"
        case .normal: return "평온해요"
        }
    }
}

enum PetAction: String, Codable, CaseIterable, Hashable {
    case feed, play, pet, sleep, clean

    var emoji: String {
        switch self {
        case .feed: return "🍎"
        case .play: return "⚡"
        case .pet: return "🤚"
        case .sleep: return "🌙"
        case .clean: return "🧹"
        }
    }

    var label: String {
        switch self {
        case .feed: return "밥"
        case .play: return "놀기"
        case .pet: return "쓰담"
        case .sleep: return "재우기"
        case .clean: return "청소"
        }
    }
}

enum ReactionKind: String, Codable, Hashable {
    case eat, play, love, clean, sleep, wake, refuse, levelUp, evolve
}

struct Reaction: Codable, Hashable {
    var text: String
    var kind: ReactionKind
    var expires: Date
}

// MARK: - Tuning

enum PetRules {
    // Stat changes per hour.
    static let fullnessDecayAwake = 6.0
    static let fullnessDecayAsleep = 2.5
    static let happinessDecayAwake = 4.0
    static let happinessDecayAsleep = 1.0
    static let energyDecayAwake = 5.0
    static let energyGainAsleep = 14.0

    static let hoursPerPoop = 3.5
    static let maxPoops = 4

    static let evolveLevel = 5
    static let crownLevel = 10

    /// Simulation step. Small enough that thresholds (auto sleep / wake, poop) land on time.
    static let step: TimeInterval = 5 * 60
    /// After this long everything has bottomed out anyway, so don't simulate further back.
    static let maxSimulated: TimeInterval = 3 * 24 * 3600
    static let reactionDuration: TimeInterval = 20 * 60

    static func xpToNextLevel(_ level: Int) -> Int { 20 + level * 10 }
}

// MARK: - State

struct PetState: Codable, Equatable {
    var name: String = "피카츄"
    var birthDate: Date
    var lastUpdated: Date

    var fullness: Double = 80
    var happiness: Double = 80
    var energy: Double = 90
    var poops: Int = 0
    var poopProgress: Double = 0
    var isSleeping: Bool = false

    var level: Int = 1
    var xp: Int = 0
    var careCount: Int = 0
    var lastPetXPAt: Date?
    var reaction: Reaction?

    init(now: Date = .now) {
        birthDate = now
        lastUpdated = now
    }

    var stage: PetStage { level >= PetRules.evolveLevel ? .pikachu : .pichu }
    var xpToNext: Int { PetRules.xpToNextLevel(level) }
    var xpProgress: Double { Double(xp) / Double(xpToNext) }

    var daysTogether: Int {
        (Calendar.current.dateComponents([.day], from: birthDate, to: lastUpdated).day ?? 0) + 1
    }

    var mood: PetMood {
        if isSleeping { return .sleeping }
        if (fullness < 10 && happiness < 25) || poops >= PetRules.maxPoops { return .sick }
        if fullness < 30 { return .hungry }
        if poops >= 2 { return .dirty }
        if energy < 25 { return .sleepy }
        if happiness < 35 { return .sad }
        if fullness >= 60 && happiness >= 70 && energy >= 40 { return .happy }
        return .normal
    }

    /// What the pet is saying right now: a recent reaction, otherwise a mood line.
    var speech: String {
        if let reaction { return reaction.text }
        let lines: [String]
        switch mood {
        case .sleeping: lines = ["Zzz…", "피카… 쿨…", "(새근새근)"]
        case .sick: lines = ["피…카… 🤒", "몸이 안 좋아…"]
        case .hungry: lines = ["꼬르륵… 🍎", "피카… (배고파)", "케첩 먹고 싶어 🍅"]
        case .dirty: lines = ["피카! (치워줘) 💩", "냄새나…"]
        case .sleepy: lines = ["피카아… (졸려)", "하암~ 🥱"]
        case .sad: lines = ["놀아줘! ⚡", "피카… (심심해)"]
        case .happy: lines = ["피카피카! ⚡", "피카~♪", "피-카-츄!", "오늘 최고야! ✨"]
        case .normal: lines = ["피카?", "피카츄!", "피카피~"]
        }
        // Stable for a quarter hour so widgets don't flicker between reloads.
        let slot = Int(lastUpdated.timeIntervalSince1970 / 900)
        return lines[slot % lines.count]
    }
}

// MARK: - Simulation

extension PetState {
    /// The state as it will be at `date`, with stats decayed over the elapsed time.
    func advanced(to date: Date) -> PetState {
        var s = self
        guard date > s.lastUpdated else { return s }
        var t = max(s.lastUpdated, date.addingTimeInterval(-PetRules.maxSimulated))
        while t < date {
            let dt = min(PetRules.step, date.timeIntervalSince(t))
            t += dt
            s.tick(hours: dt / 3600, at: t)
        }
        s.lastUpdated = date
        if let r = s.reaction, r.expires <= date { s.reaction = nil }
        return s
    }

    private mutating func tick(hours h: Double, at time: Date) {
        if isSleeping {
            fullness -= PetRules.fullnessDecayAsleep * h
            happiness -= PetRules.happinessDecayAsleep * h
            energy += PetRules.energyGainAsleep * h
            if energy >= 100 {
                energy = 100
                isSleeping = false
                react("잘 잤다! ☀️", .wake, at: time)
            }
        } else {
            fullness -= PetRules.fullnessDecayAwake * h
            happiness -= currentHappinessDecay * h
            energy -= PetRules.energyDecayAwake * h
            poopProgress += h / PetRules.hoursPerPoop * (fullness > 30 ? 1 : 0.4)
            if poopProgress >= 1 {
                poopProgress -= 1
                poops = min(poops + 1, PetRules.maxPoops)
            }
            if energy <= 0 {
                energy = 0
                isSleeping = true
                react("지쳐서 잠들었어… 💤", .sleep, at: time)
            }
        }
        clamp()
    }

    /// Happiness loss per hour given current conditions.
    var currentHappinessDecay: Double {
        if isSleeping { return PetRules.happinessDecayAsleep }
        var d = PetRules.happinessDecayAwake
        if fullness < 20 { d += 3 }
        if poops >= 3 { d += 3 }
        if energy < 15 { d += 2 }
        return d
    }

    private mutating func clamp() {
        fullness = min(max(fullness, 0), 100)
        happiness = min(max(happiness, 0), 100)
        energy = min(max(energy, 0), 100)
    }

    private mutating func react(_ text: String, _ kind: ReactionKind, at date: Date) {
        reaction = Reaction(text: text, kind: kind, expires: date.addingTimeInterval(PetRules.reactionDuration))
    }

    private mutating func gainXP(_ amount: Int, at date: Date) {
        let wasStage = stage
        xp += amount
        var leveled = false
        while xp >= xpToNext {
            xp -= xpToNext
            level += 1
            leveled = true
        }
        guard leveled else { return }
        if stage != wasStage {
            react("피츄가 피카츄로 진화했다! ✨", .evolve, at: date)
        } else if level == PetRules.crownLevel {
            react("Lv.\(level)! 왕관 획득 👑", .levelUp, at: date)
        } else {
            react("레벨 업! Lv.\(level) ⬆️", .levelUp, at: date)
        }
    }

    // MARK: Actions

    /// Applies a care action at `now`. Decay up to `now` is applied first.
    mutating func apply(_ action: PetAction, at now: Date = .now) {
        self = advanced(to: now)
        switch action {
        case .feed: feed(now)
        case .play: play(now)
        case .pet: pet(now)
        case .sleep: toggleSleep(now)
        case .clean: clean(now)
        }
    }

    private static let foods: [(emoji: String, name: String)] = [
        ("🍎", "사과"), ("🍙", "주먹밥"), ("🍅", "케첩"), ("🍓", "딸기"), ("🍰", "케이크"),
    ]

    private mutating func feed(_ now: Date) {
        if isSleeping { return react("쿨… (자는 중이야)", .refuse, at: now) }
        if fullness >= 95 {
            happiness -= 2
            clamp()
            return react("배불러~ 더는 못 먹어!", .refuse, at: now)
        }
        let food = Self.foods[Int(now.timeIntervalSince1970 / 60) % Self.foods.count]
        fullness += 25
        happiness += food.name == "케첩" ? 10 : 3
        poopProgress += 0.2
        careCount += 1
        clamp()
        react(food.name == "케첩" ? "케첩 최고야!! \(food.emoji)" : "냠냠! \(food.name) \(food.emoji)", .eat, at: now)
        gainXP(5, at: now)
    }

    private mutating func play(_ now: Date) {
        if isSleeping { return react("쿨… (자는 중이야)", .refuse, at: now) }
        if energy < 15 { return react("피곤해… 재워줘 🥱", .refuse, at: now) }
        if fullness < 10 { return react("배고파서 못 놀아… 🍎", .refuse, at: now) }
        happiness += 20
        energy -= 12
        fullness -= 6
        careCount += 1
        clamp()
        react(["피카피카! ⚡ 신나!", "백만볼트! ⚡⚡", "공놀이 재밌어! ⚾️"][careCount % 3], .play, at: now)
        gainXP(8, at: now)
    }

    private mutating func pet(_ now: Date) {
        if isSleeping {
            happiness += 2
            clamp()
            return react("(뒤척뒤척) 쿨…", .love, at: now)
        }
        happiness += 6
        careCount += 1
        clamp()
        react(["피카~ ♡", "찌릿찌릿 ♡", "헤헤 ♡"][careCount % 3], .love, at: now)
        // Petting is free, so only reward XP every few minutes.
        if lastPetXPAt.map({ now.timeIntervalSince($0) > 5 * 60 }) ?? true {
            lastPetXPAt = now
            gainXP(2, at: now)
        }
    }

    private mutating func toggleSleep(_ now: Date) {
        if isSleeping {
            isSleeping = false
            if energy < 50 {
                happiness -= 10
                clamp()
                react("으앙 더 잘래! 😫", .wake, at: now)
            } else {
                happiness += 5
                clamp()
                react("잘 잤다! ☀️", .wake, at: now)
                gainXP(5, at: now)
            }
        } else {
            if energy > 80 { return react("안 졸려! 더 놀래 ⚡", .refuse, at: now) }
            isSleeping = true
            careCount += 1
            react("잘 자… 💤", .sleep, at: now)
        }
    }

    private mutating func clean(_ now: Date) {
        if poops == 0 { return react("이미 깨끗해! ✨", .refuse, at: now) }
        poops = 0
        happiness += 5
        careCount += 1
        clamp()
        react("반짝반짝 ✨ 고마워!", .clean, at: now)
        gainXP(4, at: now)
    }
}

// MARK: - Projections (used by the Live Activity to animate bars without updates)

extension PetState {
    /// When fullness will reach 0 at the current rate.
    var fullnessEmptyDate: Date {
        let rate = isSleeping ? PetRules.fullnessDecayAsleep : PetRules.fullnessDecayAwake
        return lastUpdated.addingTimeInterval(fullness / rate * 3600)
    }

    /// When happiness will reach 0 at the current rate.
    var happinessEmptyDate: Date {
        lastUpdated.addingTimeInterval(happiness / currentHappinessDecay * 3600)
    }

    /// The window over which energy goes 0→100 (asleep) or 100→0 (awake), placed so that
    /// "now" sits at the current energy level.
    var energyWindow: ClosedRange<Date> {
        let rate = isSleeping ? PetRules.energyGainAsleep : PetRules.energyDecayAwake
        let full = 100 / rate * 3600
        if isSleeping {
            let start = lastUpdated.addingTimeInterval(-energy / rate * 3600)
            return start...start.addingTimeInterval(full)
        } else {
            let end = lastUpdated.addingTimeInterval(energy / rate * 3600)
            return end.addingTimeInterval(-full)...end
        }
    }
}

// MARK: - Preview

extension PetState {
    /// A healthy, mid-level Pikachu for widget placeholders and the gallery.
    static var preview: PetState {
        var s = PetState(now: .now)
        s.level = 6
        s.xp = 30
        s.fullness = 72
        s.happiness = 85
        s.energy = 64
        return s
    }
}
