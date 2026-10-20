import Combine
import SwiftUI
import WidgetKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var state = PetStore.shared.load()
    @State private var statusBarOn = PetStore.shared.statusBarEnabled
    @State private var floaters: [Floater] = []
    @State private var careTick = 0
    @State private var renaming = false
    @State private var draftName = ""
    @State private var confirmReset = false

    // Widgets and the Dynamic Island can change the pet while the app is open.
    private let ticker = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                sceneCard
                actionGrid
                statsCard
                statusBarCard
                widgetGuide
                Button("처음부터 다시 키우기", role: .destructive) { confirmReset = true }
                    .font(.footnote)
                    .padding(.top, 8)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .onReceive(ticker) { _ in state = PetStore.shared.load() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            state = PetStore.shared.load()
            syncOutside()
        }
        .sensoryFeedback(.impact(weight: .light), trigger: careTick)
        .alert("이름 짓기", isPresented: $renaming) {
            TextField("피카츄", text: $draftName)
            Button("저장") {
                state = PetStore.shared.rename(draftName)
                syncOutside()
            }
            Button("취소", role: .cancel) {}
        }
        .confirmationDialog("정말 처음부터 다시 키울까요?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("다시 시작", role: .destructive) {
                state = PetStore.shared.reset()
                syncOutside()
            }
        } message: {
            Text("레벨과 진화 상태가 모두 초기화돼요.")
        }
    }

    // MARK: Sections

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Button {
                    draftName = state.name
                    renaming = true
                } label: {
                    HStack(spacing: 6) {
                        Text(state.name).font(.system(.largeTitle, design: .rounded).weight(.heavy))
                        Image(systemName: "pencil").font(.headline).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                Text("\(state.stage.displayName) · 함께한 지 \(state.daysTogether)일째 · 돌봄 \(state.careCount)회")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("Lv.\(state.level)")
                .font(.system(.title2, design: .rounded).weight(.heavy))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(PetColors.xp, in: Capsule())
                .foregroundStyle(PetColors.ink)
        }
    }

    private var sceneCard: some View {
        ZStack {
            PetBackground(sleeping: state.isSleeping)
            VStack(spacing: 8) {
                SpeechBubble(text: state.speech, font: .headline)
                    .animation(.snappy, value: state.speech)
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let excited = state.mood == .happy || state.reaction != nil
                    let hop: Double = state.isSleeping ? 0 : abs(sin(t * (excited ? 5 : 2.2))) * (excited ? 16 : 5)
                    let breathe: Double = state.isSleeping ? 1 + sin(t * 1.6) * 0.025 : 1
                    PetScene(state: state, decorationSize: 26)
                        .scaleEffect(breathe, anchor: .bottom)
                        .offset(y: -hop)
                }
                .frame(height: 200)
                .contentShape(Rectangle())
                .onTapGesture { perform(.pet) }
                Text("\(state.mood.emoji) \(state.mood.label)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(state.isSleeping ? .white.opacity(0.85) : PetColors.ink.opacity(0.7))
            }
            .padding(.vertical, 20)
            ForEach(floaters) { FloaterView(floater: $0) }
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .animation(.easeInOut(duration: 0.6), value: state.isSleeping)
    }

    private var actionGrid: some View {
        HStack(spacing: 8) {
            ForEach(PetAction.allCases, id: \.self) { action in
                Button { perform(action) } label: {
                    ActionLabel(action: action, isSleeping: state.isSleeping)
                        .frame(height: 56)
                        .background(Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var statsCard: some View {
        VStack(spacing: 10) {
            statRow("배부름", "🍎", state.fullness, PetColors.fullness)
            statRow("기분", "💗", state.happiness, PetColors.happiness)
            statRow("체력", "⚡", state.energy, PetColors.energy)
            statRow("경험치", "⭐️", state.xpProgress * 100, PetColors.xp,
                    trailing: "\(state.xp)/\(state.xpToNext)")
            if state.stage == .pichu {
                Text("Lv.\(PetRules.evolveLevel)이 되면 피카츄로 진화해요 ✨")
                    .font(.caption).foregroundStyle(.secondary)
            } else if state.level < PetRules.crownLevel {
                Text("Lv.\(PetRules.crownLevel)이 되면 왕관을 받아요 👑")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func statRow(_ title: String, _ icon: String, _ value: Double, _ color: Color,
                         trailing: String? = nil) -> some View {
        HStack(spacing: 8) {
            Text(title).font(.subheadline.weight(.semibold)).frame(width: 48, alignment: .leading)
            StatBar(icon: icon, value: value, color: color, height: 10)
            Text(trailing ?? "\(Int(value.rounded()))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
        }
    }

    private var statusBarCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $statusBarOn) {
                Label("다이내믹 아일랜드에 띄우기", systemImage: "rectangle.topthird.inset.filled")
                    .font(.headline)
            }
            .tint(PetColors.xp)
            .onChange(of: statusBarOn) { _, on in
                PetStore.shared.statusBarEnabled = on
                Task {
                    if on { await StatusBarPet.sync(state) } else { await StatusBarPet.stop() }
                }
            }
            Text("iOS는 앱이 상태바에 직접 아이콘을 넣는 걸 막아둬서, 상태바 바로 옆 다이내믹 아일랜드에 피카츄가 살아요. 꾹 누르면 바로 밥 주고 놀아줄 수 있고, 배부름 링은 실시간으로 줄어들어요. 잠금 화면에도 떠요.")
                .font(.footnote).foregroundStyle(.secondary)
            Text("iOS가 8시간쯤 지나면 자동으로 내리는데, 위젯 버튼을 누르거나 앱을 열면 다시 올라와요.")
                .font(.footnote).foregroundStyle(.secondary)
            if !StatusBarPet.isAllowed {
                Text("⚠️ 설정 › 피카츄 › '실시간 현황'을 켜주세요.")
                    .font(.footnote.weight(.semibold)).foregroundStyle(.orange)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var widgetGuide: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("위젯 추가하기", systemImage: "square.grid.2x2").font(.headline)
            Text("홈 화면: 빈 곳을 길게 누르기 → 왼쪽 위 '편집' → '위젯 추가' → '피카츄'. 작은/중간/큰 크기 모두 버튼으로 바로 돌볼 수 있어요.")
            Text("잠금 화면: 잠금 화면을 길게 누르기 → '사용자화' → 시계 위/아래 위젯 칸에 '피카츄' 추가.")
            Text("Siri: \"피카츄 밥 주기\", \"피카츄 놀아주기\" — 단축어·액션 버튼에도 연결돼요.")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: Actions

    private func perform(_ action: PetAction) {
        let before = state
        withAnimation(.snappy) { state = PetStore.shared.apply(action) }
        careTick += 1
        if state.reaction?.kind != .refuse {
            spawnFloaters(for: action, leveledUp: state.level > before.level)
        }
        syncOutside()
    }

    /// Pushes the new state to the widgets and the Dynamic Island.
    private func syncOutside() {
        WidgetCenter.shared.reloadAllTimelines()
        let snapshot = state
        Task { await StatusBarPet.sync(snapshot) }
    }

    private func spawnFloaters(for action: PetAction, leveledUp: Bool) {
        let emoji: String
        switch action {
        case .feed: emoji = "😋"
        case .play: emoji = "⚡"
        case .pet: emoji = "💛"
        case .sleep: emoji = state.isSleeping ? "💤" : "☀️"
        case .clean: emoji = "✨"
        }
        let new = (0..<(leveledUp ? 6 : 3)).map { i in
            Floater(emoji: leveledUp && i.isMultiple(of: 2) ? "⭐️" : emoji,
                    x: CGFloat.random(in: -70...70), delay: Double(i) * 0.08)
        }
        floaters.append(contentsOf: new)
        let ids = Set(new.map(\.id))
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            floaters.removeAll { ids.contains($0.id) }
        }
    }
}

// MARK: - Floating emoji

struct Floater: Identifiable {
    let id = UUID()
    let emoji: String
    let x: CGFloat
    let delay: Double
}

private struct FloaterView: View {
    let floater: Floater
    @State private var risen = false

    var body: some View {
        Text(floater.emoji)
            .font(.system(size: 30))
            .offset(x: floater.x, y: risen ? -110 : 10)
            .opacity(risen ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 1.2).delay(floater.delay)) { risen = true }
            }
            .allowsHitTesting(false)
    }
}

#Preview {
    ContentView()
}
