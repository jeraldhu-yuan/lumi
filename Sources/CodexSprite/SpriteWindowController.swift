import AppKit

enum SpriteMood {
    case idle
    case listening
    case reading
    case thinking
    case threadActive
    case working
    case success
    case failed
}

struct SpriteSheet {
    let image: NSImage?
    let columns: Int
    let frameSize: Int

    init(
        relativePath: [String] = ["Assets", "ChibiAssistant", "sprite-sheet.png"],
        columns: Int = 4,
        frameSize: Int = 256
    ) {
        self.columns = columns
        self.frameSize = frameSize

        let resourceURL = relativePath.reduce(Bundle.main.resourceURL) { url, component in
            url?.appendingPathComponent(component)
        }
        let projectURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let developmentURL = relativePath.reduce(projectURL) { url, component in
            url.appendingPathComponent(component)
        }

        if let resourceURL, let image = Self.loadImage(at: resourceURL) {
            self.image = image
        } else if let image = Self.loadImage(at: developmentURL) {
            self.image = image
        } else {
            self.image = nil
        }
    }

    private static func loadImage(at url: URL) -> NSImage? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        if let representation = image.representations.first {
            image.size = NSSize(width: representation.pixelsWide, height: representation.pixelsHigh)
        }
        return image
    }
}

private enum SheetFrame: Int {
    case neutral = 0
    case blink = 1
    case greet = 2
    case surprised = 3
    case curious = 4
    case point = 5
    case flyLeft = 7
    case flyRight = 8
    case sitting = 9
    case command = 10
    case wave = 11
    case sleepy = 12
    case upset = 13
    case calm = 14
    case sleep = 15
}

private enum SupplementalFrame: Int {
    case neutral = 0
    case blink = 1
    case lookLeft = 2
    case lookRight = 3
    case sleepy = 4
    case rubEyes = 5
    case yawn = 6
    case awakeSmile = 7
    case flyRightA = 8
    case flyRightB = 9
    case flyLeftA = 10
    case flyLeftB = 11
    case question = 12
    case point = 13
    case working = 14
    case wave = 15
}

private enum ExtraFrame: Int {
    case sittingBlink = 0
    case noticeProximity = 1
    case listeningPrompt = 2
    case readingInput = 3
    case thinking = 4
    case noticeTransition = 5
    case listeningTransition = 6
    case readingTransition = 7
    case workingTransition = 8
    case listeningPromptRight = 9
    case readingInputRight = 10
    case thinkingRight = 11
    case noticeTransitionRight = 12
    case listeningTransitionRight = 13
    case readingTransitionRight = 14
    case workingTransitionRight = 15
}

private enum StandingFrame: Int {
    case frontNeutral = 0
    case frontBlink = 1
    case gazeUpRight = 2
    case gazeUp = 3
    case gazeUpLeft = 4
    case gazeRight = 5
    case gazeDownRight = 6
    case gazeDown = 7
    case gazeDownLeft = 8
    case gazeLeft = 9
}

private enum SittingFrame: Int {
    case frontNeutral = 0
    case frontBlink = 1
    case gazeUpRight = 2
    case gazeUp = 3
    case gazeUpLeft = 4
    case gazeRight = 5
    case gazeDownRight = 6
    case gazeDown = 7
    case gazeDownLeft = 8
    case gazeLeft = 9
}

private enum SleepWakeFrame: Int {
    case sleepDeep = 0
    case sleepShift = 1
    case wakeSleepySit = 2
    case wakeRubEyes = 3
    case wakeHelloSit = 4
    case wakeStandingReady = 5
}

private enum ActionFrame: Int {
    case flyLeftA = 0
    case flyLeftB = 1
    case flyRightA = 2
    case flyRightB = 3
    case thinking = 4
    case happyWave = 5
}

private enum GazeDirection {
    case up
    case upRight
    case right
    case downRight
    case down
    case downLeft
    case left
    case upLeft

    var standingFrame: StandingFrame {
        switch self {
        case .up:
            return .gazeUp
        case .upRight:
            return .gazeUpRight
        case .right:
            return .gazeRight
        case .downRight:
            return .gazeDownRight
        case .down:
            return .gazeDown
        case .downLeft:
            return .gazeDownLeft
        case .left:
            return .gazeLeft
        case .upLeft:
            return .gazeUpLeft
        }
    }

    var sittingFrame: SittingFrame {
        switch self {
        case .up:
            return .gazeUp
        case .upRight:
            return .gazeUpRight
        case .right:
            return .gazeRight
        case .downRight:
            return .gazeDownRight
        case .down:
            return .gazeDown
        case .downLeft:
            return .gazeDownLeft
        case .left:
            return .gazeLeft
        case .upLeft:
            return .gazeUpLeft
        }
    }


    static func from(deltaX: CGFloat, deltaY: CGFloat) -> GazeDirection {
        let degrees = atan2(deltaY, deltaX) * 180 / .pi

        switch degrees {
        case -22.5..<22.5:
            return .right
        case 22.5..<67.5:
            return .upRight
        case 67.5..<112.5:
            return .up
        case 112.5..<157.5:
            return .upLeft
        case 157.5...180, -180..<(-157.5):
            return .left
        case -157.5..<(-112.5):
            return .downLeft
        case -112.5..<(-67.5):
            return .down
        default:
            return .downRight
        }
    }
}

private enum AttentionFrame {
    case notice
    case listeningPrompt
    case readingInput
    case thinking
    case noticeTransition
    case listeningTransition
    case readingTransition
    case workingTransition

    var left: ExtraFrame {
        switch self {
        case .notice:
            return .noticeProximity
        case .listeningPrompt:
            return .listeningPrompt
        case .readingInput:
            return .readingInput
        case .thinking:
            return .thinking
        case .noticeTransition:
            return .noticeTransition
        case .listeningTransition:
            return .listeningTransition
        case .readingTransition:
            return .readingTransition
        case .workingTransition:
            return .workingTransition
        }
    }

    var right: ExtraFrame {
        switch self {
        case .notice:
            return .noticeTransitionRight
        case .listeningPrompt:
            return .listeningPromptRight
        case .readingInput:
            return .readingInputRight
        case .thinking:
            return .thinkingRight
        case .noticeTransition:
            return .noticeTransitionRight
        case .listeningTransition:
            return .listeningTransitionRight
        case .readingTransition:
            return .readingTransitionRight
        case .workingTransition:
            return .workingTransitionRight
        }
    }
}

@MainActor
final class SpriteWindowController {
    let window: NSPanel
    private let spriteView: SpriteView

    init(onClick: @escaping () -> Void) {
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = NSSize(width: 128, height: 128)
        let origin = NSPoint(
            x: visibleFrame.maxX - size.width - 28,
            y: visibleFrame.minY + 96
        )

        window = NSPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 2)
        window.collectionBehavior = [.ignoresCycle]
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false

        spriteView = SpriteView(frame: NSRect(origin: .zero, size: size), onClick: onClick)
        window.contentView = spriteView
    }

    func show() {
        window.orderFrontRegardless()
        spriteView.start()
    }

    func setMood(_ mood: SpriteMood) {
        spriteView.setMood(mood)
    }

    func face(point: NSPoint) {
        spriteView.face(point: point)
    }
}

final class SpriteView: NSView {
    private var mood: SpriteMood = .idle {
        didSet {
            if oldValue != mood {
                moodTicks = 0
                userInactivityTicks = 0
                wanderTarget = nil
                isAutoFlying = false
                greetingTicks = 0
                greetingTotalTicks = 0
                curiosityTicks = 0
                curiosityTotalTicks = 0
                curiosityWillTravel = false
                investigateTicks = 0
                investigateTotalTicks = 0
                dragReleaseTicks = 0
                dragReleaseTotalTicks = 0
                proximityTicks = 0
                cursorGazeDirection = nil
                if mood != .listening && mood != .reading {
                    queuedPromptMood = nil
                }
            }
            needsDisplay = true
        }
    }

    private static let sitAfterTicks = 900
    private static let drowsyAfterTicks = 3_600
    private static let sleepAfterTicks = 4_500
    private static let sleepTransitionTicks = 84
    private static let userAttentionAfterClickTicks = 900
    private static let supplementalFrameOffset = 1_000
    private static let extraFrameOffset = 2_000
    private static let standingFrameOffset = 3_000
    private static let sittingFrameOffset = 4_000
    private static let sleepWakeFrameOffset = 5_000
    private static let actionFrameOffset = 6_000

    private let onClick: () -> Void
    private let spriteSheet = SpriteSheet()
    private let supplementalSpriteSheet = SpriteSheet(
        relativePath: ["Assets", "ChibiAssistant", "generated", "supplemental-sheet.png"]
    )
    private let extraSpriteSheet = SpriteSheet(
        relativePath: ["Assets", "ChibiAssistant", "generated", "extra-sheet.png"]
    )
    private let standingSpriteSheet = SpriteSheet(
        relativePath: ["Assets", "ChibiAssistant", "generated", "standing-orientations", "standing-orientations-sheet.png"],
        columns: 5
    )
    private let sittingSpriteSheet = SpriteSheet(
        relativePath: ["Assets", "ChibiAssistant", "generated", "sitting-orientations", "sitting-orientations-sheet.png"],
        columns: 5
    )
    private let sleepWakeSpriteSheet = SpriteSheet(
        relativePath: ["Assets", "ChibiAssistant", "generated", "sleep-wake", "sleep-wake-sheet.png"],
        columns: 6
    )
    private let actionSpriteSheet = SpriteSheet(
        relativePath: ["Assets", "ChibiAssistant", "generated", "action-sprites", "action-sprites-sheet.png"],
        columns: 6
    )
    private var animationTimer: Timer?
    private var frameTick = 0
    private var moodTicks = 0
    private var userInactivityTicks = 0
    private var wanderTarget: NSPoint?
    private var curiosityCooldownTicks = 360
    private var curiosityTicks = 0
    private var curiosityTotalTicks = 0
    private var curiosityWillTravel = false
    private var investigateTicks = 0
    private var investigateTotalTicks = 0
    private var interactionPauseTicks = 0
    private var isAutoFlying = false
    private var facingLeft = false
    private var greetingTicks = 0
    private var greetingTotalTicks = 0
    private var greetingWasFromRest = false
    private var greetingWasFromSleep = false
    private var wasRestingOnMouseDown = false
    private var wasSleepingOnMouseDown = false
    private var dragInProgress = false
    private var mouseHoldTicks = 0
    private var dragReleaseTicks = 0
    private var dragReleaseTotalTicks = 0
    private var dragVelocity = CGVector(dx: 0, dy: 0)
    private var mouseDownLocation: NSPoint = .zero
    private var dragged = false
    private var proximityTicks = 0
    private var cursorGazeDirection: GazeDirection?
    private var queuedPromptMood: SpriteMood?

    init(frame frameRect: NSRect, onClick: @escaping () -> Void) {
        self.onClick = onClick
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = false
        toolTip = "Ask Codex"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    func start() {
        guard animationTimer == nil else { return }
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 12.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.frameTick = (self.frameTick + 1) % 1440
            if self.mood != .idle {
                self.moodTicks += 1
            }

            if self.greetingTicks > 0 {
                self.greetingTicks -= 1
                if self.greetingTicks == 0, let queuedPromptMood = self.queuedPromptMood {
                    self.queuedPromptMood = nil
                    self.setMood(queuedPromptMood)
                }
            }

            if self.dragInProgress {
                self.mouseHoldTicks += 1
            } else if self.dragReleaseTicks > 0 {
                self.dragReleaseTicks -= 1
                if self.dragReleaseTicks == 0 {
                    self.dragReleaseTotalTicks = 0
                }
            }

            if self.mood == .idle && !self.dragInProgress {
                self.userInactivityTicks += 1
            }

            self.advanceLife()
            self.advanceMouseAwareness()
            self.needsDisplay = true
        }
    }

    func setMood(_ nextMood: SpriteMood) {
        if (nextMood == .listening || nextMood == .reading), greetingTicks > 0 {
            queuedPromptMood = nextMood
            return
        }

        mood = nextMood
    }

    func face(point: NSPoint) {
        guard let window else { return }
        facingLeft = point.x < window.frame.midX
        cursorGazeDirection = GazeDirection.from(deltaX: point.x - window.frame.midX, deltaY: point.y - window.frame.midY)
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownLocation = event.locationInWindow
        dragged = false
        dragInProgress = true
        mouseHoldTicks = 0
        dragReleaseTicks = 0
        dragReleaseTotalTicks = 0
        dragVelocity = CGVector(dx: 0, dy: 0)
        wasRestingOnMouseDown = userInactivityTicks >= Self.sitAfterTicks
        wasSleepingOnMouseDown = userInactivityTicks >= Self.sleepAfterTicks
        if !wasRestingOnMouseDown {
            userInactivityTicks = 0
        }
        curiosityCooldownTicks = Self.userAttentionAfterClickTicks
        curiosityTicks = 0
        curiosityTotalTicks = 0
        curiosityWillTravel = false
        investigateTicks = 0
        investigateTotalTicks = 0
        wanderTarget = nil
        isAutoFlying = false
        interactionPauseTicks = 48
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let location = event.locationInWindow
        let dx = location.x - mouseDownLocation.x
        let dy = location.y - mouseDownLocation.y

        if abs(dx) + abs(dy) > 4 {
            dragged = true
        }
        if abs(dx) > 0.3 {
            facingLeft = dx < 0
        }
        dragVelocity = CGVector(dx: dx, dy: dy)

        wanderTarget = nil
        isAutoFlying = false

        var frame = window.frame
        frame.origin.x += dx
        frame.origin.y += dy
        frame.origin = clamped(origin: frame.origin, for: window)
        window.setFrame(frame, display: true)
    }

    override func mouseUp(with event: NSEvent) {
        dragInProgress = false
        interactionPauseTicks = dragged ? 96 : 300
        curiosityCooldownTicks = max(curiosityCooldownTicks, dragged ? 120 : Self.userAttentionAfterClickTicks)
        wanderTarget = nil
        isAutoFlying = false

        if !dragged {
            dragReleaseTicks = 0
            dragReleaseTotalTicks = 0
            startGreeting(fromRest: wasRestingOnMouseDown, fromSleep: wasSleepingOnMouseDown)
            onClick()
        } else {
            startDragRelease()
        }
    }

    private func startDragRelease() {
        dragReleaseTotalTicks = 42
        dragReleaseTicks = dragReleaseTotalTicks
        userInactivityTicks = 0
        interactionPauseTicks = max(interactionPauseTicks, dragReleaseTotalTicks + 36)
        curiosityCooldownTicks = max(curiosityCooldownTicks, dragReleaseTotalTicks + 180)
        dragVelocity = CGVector(dx: 0, dy: 0)
    }

    private func startGreeting(fromRest: Bool, fromSleep: Bool) {
        greetingWasFromRest = fromRest
        greetingWasFromSleep = fromSleep
        greetingTotalTicks = fromSleep ? 126 : (fromRest ? 84 : 66)
        greetingTicks = greetingTotalTicks
        userInactivityTicks = 0
        interactionPauseTicks = max(interactionPauseTicks, greetingTotalTicks + 24)
        curiosityCooldownTicks = max(curiosityCooldownTicks, greetingTotalTicks + Self.userAttentionAfterClickTicks)
    }

    private func advanceLife() {
        guard let window else { return }

        if (mood == .success || mood == .failed) && moodTicks > 180 {
            setMood(.idle)
            return
        }

        if dragInProgress {
            isAutoFlying = false
            wanderTarget = nil
            return
        }

        if dragReleaseTicks > 0 {
            isAutoFlying = false
            wanderTarget = nil
            return
        }

        if mood != .idle {
            isAutoFlying = false
            wanderTarget = nil
            curiosityTicks = 0
            curiosityTotalTicks = 0
            curiosityWillTravel = false
            investigateTicks = 0
            investigateTotalTicks = 0
            curiosityCooldownTicks = max(curiosityCooldownTicks, 96)
            return
        }

        if greetingTicks > 0 {
            isAutoFlying = false
            wanderTarget = nil
            return
        }

        if userInactivityTicks >= Self.sitAfterTicks {
            isAutoFlying = false
            wanderTarget = nil
            curiosityTicks = 0
            curiosityTotalTicks = 0
            curiosityWillTravel = false
            investigateTicks = 0
            investigateTotalTicks = 0
            return
        }

        if interactionPauseTicks > 0 {
            interactionPauseTicks -= 1
            isAutoFlying = false
            return
        }

        if investigateTicks > 0 {
            investigateTicks -= 1
            isAutoFlying = false
            if investigateTicks == 0 {
                investigateTotalTicks = 0
                curiosityCooldownTicks = nextCuriosityCooldownTicks()
            }
            return
        }

        if curiosityTicks > 0 {
            curiosityTicks -= 1
            isAutoFlying = false
            if curiosityTicks == 0 {
                curiosityTotalTicks = 0
                if curiosityWillTravel {
                    if wanderTarget == nil {
                        wanderTarget = nextCuriosityTarget(for: window)
                    }
                } else {
                    curiosityCooldownTicks = nextCuriosityCooldownTicks()
                }
                curiosityWillTravel = false
            }
            return
        }

        if wanderTarget == nil {
            if curiosityCooldownTicks > 0 {
                curiosityCooldownTicks -= 1
                isAutoFlying = false
                return
            }

            curiosityWillTravel = unitNoise(salt: 193) > 0.45
            if curiosityWillTravel {
                let target = nextCuriosityTarget(for: window)
                wanderTarget = target
                facingLeft = target.x < window.frame.midX
            }
            let nextCuriosity = nextCuriosityTicks(willTravel: curiosityWillTravel)
            curiosityTicks = nextCuriosity
            curiosityTotalTicks = nextCuriosity
            isAutoFlying = false
            return
        }

        guard let target = wanderTarget else {
            isAutoFlying = false
            return
        }

        let frame = window.frame
        let dx = target.x - frame.origin.x
        let dy = target.y - frame.origin.y
        let distance = sqrt(dx * dx + dy * dy)

        guard distance > 3 else {
            window.setFrameOrigin(target)
            wanderTarget = nil
            let nextInvestigation = nextInvestigationTicks()
            investigateTicks = nextInvestigation
            investigateTotalTicks = nextInvestigation
            isAutoFlying = false
            return
        }

        let speed = min(CGFloat(3.2), max(CGFloat(1.4), distance / 80.0))
        var nextOrigin = NSPoint(
            x: frame.origin.x + dx / distance * speed,
            y: frame.origin.y + dy / distance * speed
        )

        nextOrigin = clamped(origin: nextOrigin, for: window)
        facingLeft = dx < -0.2
        isAutoFlying = true
        window.setFrameOrigin(nextOrigin)
    }

    private func advanceMouseAwareness() {
        guard let window else { return }
        guard canTrackMouse else {
            proximityTicks = max(0, proximityTicks - 2)
            if proximityTicks == 0 {
                cursorGazeDirection = nil
            }
            return
        }

        let mouse = NSEvent.mouseLocation
        let nearFrame = window.frame.insetBy(dx: -150, dy: -130)
        let deltaX = mouse.x - window.frame.midX
        let deltaY = mouse.y - window.frame.midY

        if nearFrame.contains(mouse) && userInactivityTicks < Self.sleepAfterTicks {
            facingLeft = deltaX < 0
            cursorGazeDirection = GazeDirection.from(deltaX: deltaX, deltaY: deltaY)
            proximityTicks = min(96, proximityTicks + 5)
            curiosityCooldownTicks = max(curiosityCooldownTicks, 120)
        } else {
            proximityTicks = max(0, proximityTicks - 2)
            if proximityTicks == 0 {
                cursorGazeDirection = nil
            }
        }
    }

    private var canTrackMouse: Bool {
        guard !dragInProgress && dragReleaseTicks == 0 else { return false }

        switch mood {
        case .idle:
            return greetingTicks == 0 || canTrackMouseDuringGreeting
        case .listening, .reading, .threadActive:
            return true
        case .thinking, .working, .success, .failed:
            return false
        }
    }

    private var canTrackMouseDuringGreeting: Bool {
        guard greetingTicks > 0 else { return true }

        let elapsed = greetingElapsedTicks
        if greetingWasFromSleep {
            return elapsed >= 36
        }
        if greetingWasFromRest {
            return elapsed >= 26
        }
        return elapsed >= 10
    }

    private func nextCuriosityTarget(for window: NSWindow) -> NSPoint {
        let visible = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let margin: CGFloat = 28
        let frame = window.frame
        let minX = visible.minX + margin
        let maxX = max(minX, visible.maxX - frame.width - margin)
        let minY = visible.minY + margin
        let maxY = max(minY, visible.maxY - frame.height - margin)

        let current = frame.origin
        let angle = unitNoise(salt: 17) * CGFloat.pi * 2
        let distance = CGFloat(180) + unitNoise(salt: 43) * CGFloat(300)
        var x = current.x + cos(angle) * distance
        var y = current.y + sin(angle) * distance * 0.72

        if x < minX || x > maxX {
            x = current.x < visible.midX ? maxX - unitNoise(salt: 71) * 120 : minX + unitNoise(salt: 73) * 120
        }
        if y < minY || y > maxY {
            y = current.y < visible.midY ? maxY - unitNoise(salt: 89) * 90 : minY + unitNoise(salt: 97) * 90
        }

        return clamped(origin: NSPoint(x: x, y: y), for: window)
    }

    private func clamped(origin: NSPoint, for window: NSWindow) -> NSPoint {
        let visible = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let margin: CGFloat = 12
        let minX = visible.minX + margin
        let maxX = max(minX, visible.maxX - window.frame.width - margin)
        let minY = visible.minY + margin
        let maxY = max(minY, visible.maxY - window.frame.height - margin)

        return NSPoint(
            x: min(max(origin.x, minX), maxX),
            y: min(max(origin.y, minY), maxY)
        )
    }

    private func nextCuriosityTicks(willTravel: Bool) -> Int {
        if willTravel {
            return 48 + Int(unitNoise(salt: 131) * 24)
        }
        return 28 + Int(unitNoise(salt: 131) * 18)
    }

    private func nextInvestigationTicks() -> Int {
        64 + Int(unitNoise(salt: 149) * 44)
    }

    private func nextCuriosityCooldownTicks() -> Int {
        300 + Int(unitNoise(salt: 167) * 600)
    }

    private func unitNoise(salt: Int) -> CGFloat {
        let raw = sin(CGFloat(frameTick + salt) * 12.9898) * 43758.5453
        return raw - floor(raw)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        bounds.fill()

        NSGraphicsContext.current?.shouldAntialias = false

        let bobPattern: [CGFloat] = [0, 2, 4, 2]
        let bob = bobPattern[(frameTick / 2) % bobPattern.count]
        let stepFrame = (frameTick / 4) % 2 == 0
        let blink = frameTick % 48 == 0 || frameTick % 48 == 1
        let pulse = (frameTick / 3) % 2 == 0

        if drawSpriteSheetFrame() {
            return
        }

        let pixel: CGFloat = 5
        let origin = NSPoint(x: 14, y: 10 + bob)

        drawPixelShadow(pixel: pixel, origin: NSPoint(x: origin.x, y: origin.y - bob))
        drawPixelSprite(pixel: pixel, origin: origin, stepFrame: stepFrame, blink: blink, pulse: pulse)
    }

    private func drawSpriteSheetFrame() -> Bool {
        var frameIndex = spriteSheetFrameIndex
        let requestedAction = frameIndex >= Self.actionFrameOffset
        let requestedSleepWake = !requestedAction && frameIndex >= Self.sleepWakeFrameOffset
        let requestedSitting = !requestedSleepWake && frameIndex >= Self.sittingFrameOffset
        let requestedStanding = !requestedSleepWake && !requestedSitting && frameIndex >= Self.standingFrameOffset
        let requestedExtra = !requestedSleepWake && !requestedSitting && !requestedStanding && frameIndex >= Self.extraFrameOffset
        let requestedSupplemental = !requestedSleepWake && !requestedSitting && !requestedStanding && !requestedExtra && frameIndex >= Self.supplementalFrameOffset
        let selectedSheet: SpriteSheet

        if requestedAction && actionSpriteSheet.image != nil {
            selectedSheet = actionSpriteSheet
            frameIndex -= Self.actionFrameOffset
        } else if requestedAction {
            return false
        } else if requestedSleepWake && sleepWakeSpriteSheet.image != nil {
            selectedSheet = sleepWakeSpriteSheet
            frameIndex -= Self.sleepWakeFrameOffset
        } else if requestedSleepWake {
            return false
        } else if requestedSitting && sittingSpriteSheet.image != nil {
            selectedSheet = sittingSpriteSheet
            frameIndex -= Self.sittingFrameOffset
        } else if requestedSitting {
            return false
        } else if requestedStanding && standingSpriteSheet.image != nil {
            selectedSheet = standingSpriteSheet
            frameIndex -= Self.standingFrameOffset
        } else if requestedStanding {
            return false
        } else if requestedExtra && extraSpriteSheet.image != nil {
            selectedSheet = extraSpriteSheet
            frameIndex -= Self.extraFrameOffset
        } else if requestedExtra {
            selectedSheet = spriteSheet
            frameIndex = SheetFrame.sitting.rawValue
        } else if requestedSupplemental && supplementalSpriteSheet.image != nil {
            selectedSheet = supplementalSpriteSheet
            frameIndex -= Self.supplementalFrameOffset
        } else if requestedSupplemental {
            selectedSheet = spriteSheet
            frameIndex = SheetFrame.neutral.rawValue
        } else {
            selectedSheet = spriteSheet
        }

        guard let image = selectedSheet.image else { return false }

        let col = frameIndex % selectedSheet.columns
        let row = frameIndex / selectedSheet.columns
        let sourceSize = CGFloat(selectedSheet.frameSize)
        let sourceRect = NSRect(
            x: CGFloat(col) * sourceSize,
            y: image.size.height - CGFloat(row + 1) * sourceSize,
            width: sourceSize,
            height: sourceSize
        )

        let drawRect = spriteDrawRect
        drawSpriteShadow(under: drawRect)

        NSGraphicsContext.saveGraphicsState()
        let context = NSGraphicsContext.current
        context?.imageInterpolation = .none
        image.draw(
            in: drawRect,
            from: sourceRect,
            operation: .sourceOver,
            fraction: 1.0,
            respectFlipped: false,
            hints: [.interpolation: NSImageInterpolation.none]
        )
        NSGraphicsContext.restoreGraphicsState()

        if dragInProgress {
            drawDragEffects(around: drawRect)
        } else if dragReleaseTicks > 0 {
            drawDropSparkles(around: drawRect)
        }
        drawAmbientSparkles(around: drawRect)
        if shouldShowGreetingBubble {
            drawGreetingBubble(around: drawRect)
        }
        return true
    }

    private var shouldShowGreetingBubble: Bool {
        guard mood == .idle && greetingTicks > 0 else { return false }

        let elapsed = greetingElapsedTicks
        if greetingWasFromSleep {
            return elapsed >= 66
        }
        if greetingWasFromRest {
            return elapsed >= 38
        }
        return elapsed >= 10
    }

    private var spriteDrawRect: NSRect {
        let resting = mood == .idle && greetingTicks == 0 && !isAutoFlying && userInactivityTicks >= Self.sitAfterTicks
        let bobPattern: [CGFloat]
        let swayPattern: [CGFloat]

        if dragInProgress && dragged {
            bobPattern = [2, 5, 3, 0, -1, 1]
            swayPattern = [0, 1, 0, -1]
        } else if dragInProgress {
            bobPattern = [0, 1, 2, 1, 0, -1]
            swayPattern = [0]
        } else if dragReleaseTicks > 0 {
            bobPattern = [4, 1, -1, 0, 1, 0]
            swayPattern = [0]
        } else if isAutoFlying {
            bobPattern = [0, 2, 4, 3, 1, -1]
            swayPattern = [0, 1, 2, 1, 0, -1, -2, -1]
        } else if resting {
            bobPattern = [0, 0, 1, 1, 0, 0, -1, -1]
            swayPattern = [0]
        } else {
            bobPattern = [0, 1, 2, 3, 2, 1, 0, -1]
            swayPattern = [0, 0, 1, 1, 0, 0, -1, -1]
        }

        let bob = bobPattern[(frameTick / 2) % bobPattern.count]
        let sway = swayPattern[(frameTick / 5) % swayPattern.count]
        let breatheInset: CGFloat = (mood == .idle && !isAutoFlying && !dragInProgress && dragReleaseTicks == 0 && (frameTick / 18) % 2 == 0) ? 1 : 0

        return bounds
            .insetBy(dx: 7 + breatheInset, dy: 7 + breatheInset)
            .offsetBy(dx: sway, dy: bob)
    }

    private var greetingElapsedTicks: Int {
        max(0, greetingTotalTicks - greetingTicks)
    }

    private var spriteSheetFrameIndex: Int {
        if dragInProgress {
            return dragFrameIndex
        }
        if dragReleaseTicks > 0 {
            return dragReleaseFrameIndex
        }

        switch mood {
        case .idle:
            if greetingTicks > 0 {
                return greetingFrameIndex
            }
            if isAutoFlying {
                let frames: [ActionFrame] = facingLeft ? [.flyLeftA, .flyLeftB] : [.flyRightA, .flyRightB]
                return loopingAction(frames, hold: 5)
            }
            if curiosityTicks > 0 {
                return curiosityFrameIndex
            }
            if investigateTicks > 0 {
                return investigationFrameIndex
            }
            return idleFrameIndex
        case .listening:
            return listeningFrameIndex
        case .reading:
            return readingFrameIndex
        case .thinking:
            return thinkingFrameIndex
        case .threadActive:
            return loopingMixed([action(.thinking), action(.thinking), standing(.frontNeutral)], hold: 24)
        case .working:
            if moodTicks < 16 {
                return thinkingFrameIndex
            }
            return loopingMixed([action(.thinking), attention(.workingTransition), action(.thinking), standing(.frontNeutral)], hold: 12)
        case .success:
            return loopingMixed([action(.happyWave), action(.happyWave), standing(.frontNeutral)], hold: 9)
        case .failed:
            return loopingFrame([.upset, .surprised, .curious, .upset], hold: 12)
        }
    }

    private var idleFrameIndex: Int {
        if userInactivityTicks >= Self.sleepAfterTicks {
            return loopingMixed([sleepWake(.sleepDeep), sleepWake(.sleepShift)], hold: 42)
        }

        if userInactivityTicks >= Self.sleepAfterTicks - Self.sleepTransitionTicks && proximityTicks == 0 {
            return sleepTransitionFrameIndex
        }

        if userInactivityTicks >= Self.drowsyAfterTicks {
            if proximityTicks > 0 {
                return sittingProximityFrameIndex
            }
            return drowsySittingBlinkActive ? sitting(.frontBlink) : sitting(.gazeDown)
        }

        if userInactivityTicks >= Self.sitAfterTicks {
            if proximityTicks > 0 {
                return sittingProximityFrameIndex
            }
            return sittingBlinkActive ? sitting(.frontBlink) : sitting(.frontNeutral)
        }

        let cycle = frameTick % 540

        if proximityTicks > 0 {
            return proximityFrameIndex
        }

        if standingBlinkActive {
            return standing(.frontBlink)
        }

        switch cycle {
        case 70..<90:
            return standing(.gazeUp)
        case 126..<144:
            return standing(.gazeUpRight)
        case 170..<190:
            return standing(.gazeRight)
        case 230..<250:
            return standing(.gazeDownRight)
        case 290..<310:
            return standing(.gazeDown)
        case 350..<370:
            return standing(.gazeDownLeft)
        case 410..<430:
            return standing(.gazeLeft)
        case 470..<490:
            return standing(.gazeUpLeft)
        case 510..<530:
            return standing(.gazeUpRight)
        default:
            return standing(.frontNeutral)
        }
    }

    private var proximityFrameIndex: Int {
        if proximityTicks < 6 {
            return standing(.frontNeutral)
        }
        return standing(cursorGazeDirection?.standingFrame ?? .frontNeutral)
    }

    private var sittingProximityFrameIndex: Int {
        if proximityTicks < 6 {
            return sitting(.frontNeutral)
        }
        return sitting(cursorGazeDirection?.sittingFrame ?? .frontNeutral)
    }

    private var sleepTransitionFrameIndex: Int {
        let elapsed = userInactivityTicks - (Self.sleepAfterTicks - Self.sleepTransitionTicks)
        return stagedMixed([
            sleepWake(.wakeStandingReady),
            sleepWake(.wakeHelloSit),
            sleepWake(.wakeRubEyes),
            sleepWake(.wakeSleepySit),
            sleepWake(.sleepShift),
            sleepWake(.sleepDeep)
        ], elapsed: elapsed, hold: 14)
    }

    private var listeningFrameIndex: Int {
        if moodTicks >= 30 && proximityTicks > 0 {
            return proximityFrameIndex
        }

        if moodTicks < 24 {
            return stagedMixed([attention(.noticeTransition), attention(.listeningTransition), attention(.listeningPrompt)], elapsed: moodTicks, hold: 8)
        }
        return loopingMixed([attention(.listeningPrompt), attention(.listeningTransition), supplemental(.awakeSmile), attention(.listeningPrompt)], hold: 18)
    }

    private var readingFrameIndex: Int {
        if moodTicks >= 30 && proximityTicks > 0 {
            return proximityFrameIndex
        }

        if moodTicks < 24 {
            return stagedMixed([attention(.listeningTransition), attention(.readingTransition), attention(.readingInput)], elapsed: moodTicks, hold: 8)
        }
        return loopingMixed([attention(.readingInput), attention(.readingTransition), attention(.readingInput), attention(.thinking)], hold: 20)
    }

    private var thinkingFrameIndex: Int {
        if moodTicks < 30 {
            return stagedMixed([attention(.readingTransition), action(.thinking), action(.thinking)], elapsed: moodTicks, hold: 10)
        }
        return loopingMixed([action(.thinking), action(.thinking), standing(.frontNeutral)], hold: 16)
    }

    private var greetingFrameIndex: Int {
        let elapsed = greetingElapsedTicks

        if let gazeFrameIndex = greetingGazeFrameIndex(elapsed: elapsed) {
            return gazeFrameIndex
        }

        if greetingWasFromSleep {
            return sleepWakeFrameIndex(elapsed: elapsed)
        }

        if greetingWasFromRest {
            return restWakeFrameIndex(elapsed: elapsed)
        }

        return stagedMixed([primary(.surprised), supplemental(.awakeSmile), action(.happyWave), action(.happyWave), standing(.frontNeutral)], elapsed: elapsed, hold: 10)
    }

    private func greetingGazeFrameIndex(elapsed: Int) -> Int? {
        guard proximityTicks >= 6, let direction = cursorGazeDirection else { return nil }

        if greetingWasFromSleep {
            if elapsed >= 118 {
                return standing(direction.standingFrame)
            }
            if elapsed >= 44 && elapsed < 66 {
                return sitting(direction.sittingFrame)
            }
            return nil
        }

        if greetingWasFromRest {
            if elapsed >= 76 {
                return standing(direction.standingFrame)
            }
            if elapsed >= 26 && elapsed < 38 {
                return sitting(direction.sittingFrame)
            }
            return nil
        }

        if elapsed >= 30 {
            return standing(direction.standingFrame)
        }
        return nil
    }

    private var curiosityFrameIndex: Int {
        let elapsed = max(0, curiosityTotalTicks - curiosityTicks)
        if curiosityWillTravel {
            let diagonalLook = facingLeft ? standing(.gazeUpLeft) : standing(.gazeUpRight)
            let sideLook = facingLeft ? standing(.gazeLeft) : standing(.gazeRight)
            return stagedMixed([standing(.frontNeutral), diagonalLook, sideLook, diagonalLook, sideLook], elapsed: elapsed, hold: 10)
        }
        return stagedMixed([standing(.gazeUp), standing(.gazeUpRight), standing(.frontNeutral), standing(.gazeDownLeft), standing(.gazeLeft), standing(.frontNeutral)], elapsed: elapsed, hold: 8)
    }

    private var investigationFrameIndex: Int {
        let elapsed = max(0, investigateTotalTicks - investigateTicks)
        let remainingWrapUp = max(18, investigateTotalTicks / 5)

        if elapsed < 18 {
            return facingLeft ? standing(.gazeLeft) : standing(.gazeRight)
        }

        if elapsed < 34 {
            return standing(.gazeDown)
        }

        if investigateTicks < remainingWrapUp {
            return standing(.frontNeutral)
        }

        return loopingMixed([
            standing(.gazeDown),
            standing(.gazeUpRight),
            standing(.frontNeutral),
            facingLeft ? standing(.gazeLeft) : standing(.gazeRight)
        ], hold: 9)
    }

    private func sleepWakeFrameIndex(elapsed: Int) -> Int {
        switch elapsed {
        case 0..<8:
            return sleepWake(.sleepShift)
        case 8..<24:
            return sleepWake(.wakeSleepySit)
        case 24..<44:
            return sleepWake(.wakeRubEyes)
        case 44..<56:
            return sitting(.gazeDown)
        case 56..<66:
            return sitting(.frontBlink)
        case 66..<84:
            return sleepWake(.wakeHelloSit)
        case 84..<98:
            return sleepWake(.wakeStandingReady)
        case 98..<118:
            return action(.happyWave)
        default:
            return standing(.frontNeutral)
        }
    }

    private func restWakeFrameIndex(elapsed: Int) -> Int {
        switch elapsed {
        case 0..<14:
            return sleepWake(.wakeSleepySit)
        case 14..<26:
            return sleepWake(.wakeRubEyes)
        case 26..<38:
            return sitting(.frontBlink)
        case 38..<54:
            return sleepWake(.wakeHelloSit)
        case 54..<66:
            return sleepWake(.wakeStandingReady)
        case 66..<76:
            return action(.happyWave)
        default:
            return standing(.frontNeutral)
        }
    }

    private var dragFrameIndex: Int {
        if dragged {
            let frames: [ActionFrame] = facingLeft ? [.flyLeftA, .flyLeftB] : [.flyRightA, .flyRightB]
            return loopingAction(frames, hold: 4)
        }

        if wasSleepingOnMouseDown {
            return sleepWake(.sleepDeep)
        }
        if wasRestingOnMouseDown {
            return sitting(.frontNeutral)
        }

        if mouseHoldTicks < 6 {
            return primary(.surprised)
        }
        if mouseHoldTicks < 18 {
            return supplemental(.awakeSmile)
        }
        return loopingMixed([supplemental(.awakeSmile), action(.happyWave)], hold: 10)
    }

    private var dragReleaseFrameIndex: Int {
        let elapsed = max(0, dragReleaseTotalTicks - dragReleaseTicks)
        if elapsed < 8 {
            return action(facingLeft ? .flyLeftB : .flyRightB)
        }
        if elapsed < 20 {
            return supplemental(.awakeSmile)
        }
        if elapsed < 32 {
            return action(.happyWave)
        }
        return standing(.frontNeutral)
    }

    private var standingBlinkActive: Bool {
        let cycle = frameTick % 144
        return cycle == 12 || cycle == 13
            || cycle == 49 || cycle == 50
            || cycle == 88 || cycle == 89
            || cycle == 130 || cycle == 131
    }

    private var sittingBlinkActive: Bool {
        let cycle = frameTick % 168
        return cycle == 18 || cycle == 19 || cycle == 20
            || cycle == 78 || cycle == 79 || cycle == 80
            || cycle == 137 || cycle == 138 || cycle == 139
    }

    private var drowsySittingBlinkActive: Bool {
        let cycle = frameTick % 132
        return (18...26).contains(cycle) || (78...88).contains(cycle)
    }

    private func stagedFrame(_ frames: [SheetFrame], elapsed: Int, hold: Int) -> Int {
        frames[min(frames.count - 1, elapsed / hold)].rawValue
    }

    private func loopingFrame(_ frames: [SheetFrame], hold: Int) -> Int {
        frames[(frameTick / hold) % frames.count].rawValue
    }

    private func primary(_ frame: SheetFrame) -> Int {
        frame.rawValue
    }

    private func supplemental(_ frame: SupplementalFrame) -> Int {
        Self.supplementalFrameOffset + frame.rawValue
    }

    private func extra(_ frame: ExtraFrame) -> Int {
        Self.extraFrameOffset + frame.rawValue
    }

    private func standing(_ frame: StandingFrame) -> Int {
        Self.standingFrameOffset + frame.rawValue
    }

    private func sitting(_ frame: SittingFrame) -> Int {
        Self.sittingFrameOffset + frame.rawValue
    }

    private func sleepWake(_ frame: SleepWakeFrame) -> Int {
        Self.sleepWakeFrameOffset + frame.rawValue
    }

    private func action(_ frame: ActionFrame) -> Int {
        Self.actionFrameOffset + frame.rawValue
    }

    private func attention(_ frame: AttentionFrame) -> Int {
        extra(facingLeft ? frame.left : frame.right)
    }

    private func stagedSupplemental(_ frames: [SupplementalFrame], elapsed: Int, hold: Int) -> Int {
        supplemental(frames[min(frames.count - 1, elapsed / hold)])
    }

    private func loopingSupplemental(_ frames: [SupplementalFrame], hold: Int) -> Int {
        supplemental(frames[(frameTick / hold) % frames.count])
    }

    private func loopingAction(_ frames: [ActionFrame], hold: Int) -> Int {
        action(frames[(frameTick / hold) % frames.count])
    }

    private func stagedMixed(_ frames: [Int], elapsed: Int, hold: Int) -> Int {
        frames[min(frames.count - 1, elapsed / hold)]
    }

    private func loopingMixed(_ frames: [Int], hold: Int) -> Int {
        frames[(frameTick / hold) % frames.count]
    }

    private func drawSpriteShadow(under rect: NSRect) {
        let shadowY = bounds.minY + 9
        let lifted = isAutoFlying || dragInProgress || dragReleaseTicks > 0
        let focused = mood == .working || mood == .threadActive
        let width = rect.width * (lifted ? 0.22 : (focused ? 0.40 : 0.34))
        let height: CGFloat = lifted ? 4 : (focused ? 6 : 5)
        let shadowRect = NSRect(
            x: rect.midX - width / 2,
            y: shadowY,
            width: width,
            height: height
        )

        NSColor.black.withAlphaComponent(0.22).setFill()
        shadowRect.fill()
        NSColor.black.withAlphaComponent(0.10).setFill()
        shadowRect.insetBy(dx: 8, dy: -2).offsetBy(dx: 0, dy: -2).fill()
    }

    private func drawAmbientSparkles(around rect: NSRect) {
        guard mood != .failed else { return }

        let mentallyBusy = mood == .thinking || mood == .working || mood == .threadActive
        let pixel: CGFloat = (mentallyBusy || isAutoFlying) ? 3 : 2
        let alpha: CGFloat = (frameTick / 6) % 2 == 0 ? 0.88 : 0.42
        let color = statusColor.withAlphaComponent(alpha)
        let secondary = NSColor(calibratedRed: 0.38, green: 0.84, blue: 1.0, alpha: alpha * 0.72)

        let anchors: [(CGFloat, CGFloat, Int)] = [
            (-7, 0.74, 0),
            (3, 0.93, 11),
            (7, 0.48, 23),
            (-2, 0.36, 37)
        ]

        for (offsetX, yFactor, phase) in anchors {
            guard ((frameTick + phase) / 10) % 3 != 0 else { continue }
            let x = rect.midX + offsetX + CGFloat(((frameTick + phase) % 5) - 2)
            let y = rect.minY + rect.height * yFactor + CGFloat(((frameTick + phase) % 7) - 3)
            drawPixelSquare(x: x, y: y, size: pixel, color: (phase % 2 == 0) ? color : secondary)
        }

        if isAutoFlying {
            for index in 0..<4 {
                let trailX = facingLeft ? rect.maxX + CGFloat(index * 8) : rect.minX - CGFloat(index * 8)
                let trailY = rect.midY - CGFloat(index * 5) + CGFloat((frameTick + index) % 4)
                drawPixelSquare(x: trailX, y: trailY, size: CGFloat(max(1, 4 - index)), color: statusColor.withAlphaComponent(0.55 - CGFloat(index) * 0.09))
            }
        } else if mentallyBusy {
            let lift = CGFloat((frameTick / 4) % 4)
            drawPixelSquare(x: rect.maxX - 27, y: rect.maxY - 30 + lift, size: 3, color: statusColor.withAlphaComponent(0.72))
            drawPixelSquare(x: rect.maxX - 17, y: rect.maxY - 38 - lift, size: 2, color: secondary.withAlphaComponent(0.58))
        }
    }

    private func drawDragEffects(around rect: NSRect) {
        let accent = NSColor(calibratedRed: 0.36, green: 0.86, blue: 1.0, alpha: 0.92)
        let pink = NSColor(calibratedRed: 1.0, green: 0.48, blue: 0.70, alpha: 0.88)

        if !dragged {
            if wasSleepingOnMouseDown || wasRestingOnMouseDown {
                drawPixelSquare(x: rect.maxX - 18, y: rect.maxY - 18, size: 3, color: accent.withAlphaComponent(0.68))
                return
            }

            let lift = CGFloat((mouseHoldTicks % 18) / 6)
            drawPixelHeart(
                x: rect.maxX - 25,
                y: rect.maxY - 22 + lift,
                scale: 2,
                color: pink
            )
            drawPixelSquare(x: rect.minX + 19, y: rect.maxY - 18, size: 3, color: accent.withAlphaComponent(0.72))
            drawPixelSquare(x: rect.maxX - 15, y: rect.midY + 8, size: 2, color: NSColor.white.withAlphaComponent(0.78))
            return
        }

        let vertical = min(CGFloat(8), max(CGFloat(-8), dragVelocity.dy * 0.25))
        for index in 0..<5 {
            let fade = 0.75 - CGFloat(index) * 0.11
            let x = facingLeft
                ? rect.maxX - CGFloat(12 + index * 10)
                : rect.minX + CGFloat(12 + index * 10)
            let y = rect.midY - CGFloat(index * 5) - vertical + CGFloat((frameTick + index) % 4)
            drawPixelSquare(x: x, y: y, size: CGFloat(max(2, 5 - index)), color: accent.withAlphaComponent(fade))
        }

        if frameTick % 16 < 8 {
            drawPixelHeart(
                x: facingLeft ? rect.maxX - 24 : rect.minX + 15,
                y: rect.maxY - 26,
                scale: 1.5,
                color: pink.withAlphaComponent(0.78)
            )
        }
    }

    private func drawDropSparkles(around rect: NSRect) {
        let elapsed = max(0, dragReleaseTotalTicks - dragReleaseTicks)
        let progress = CGFloat(elapsed) / CGFloat(max(1, dragReleaseTotalTicks))
        let alpha = max(CGFloat(0), 0.86 - progress * 0.72)
        let blue = NSColor(calibratedRed: 0.38, green: 0.86, blue: 1.0, alpha: alpha)
        let white = NSColor.white.withAlphaComponent(alpha * 0.9)

        for index in 0..<6 {
            let spread = CGFloat(index - 2) * 9
            let rise = CGFloat(elapsed % 18) * 0.7
            let size = CGFloat(index % 2 == 0 ? 3 : 2)
            drawPixelSquare(
                x: rect.midX + spread,
                y: rect.minY + 15 + rise + CGFloat((index * 3) % 7),
                size: size,
                color: index % 2 == 0 ? blue : white
            )
        }
    }

    private func drawPixelHeart(x: CGFloat, y: CGFloat, scale: CGFloat, color: NSColor) {
        let pattern = ["01010", "11111", "11111", "01110", "00100"]
        for (rowIndex, row) in pattern.enumerated() {
            for (columnIndex, cell) in Array(row).enumerated() where cell == "1" {
                drawPixelSquare(
                    x: x + CGFloat(columnIndex) * scale,
                    y: y + CGFloat(pattern.count - rowIndex - 1) * scale,
                    size: scale,
                    color: color
                )
            }
        }
    }

    private func drawGreetingBubble(around rect: NSRect) {
        let enthusiastic = greetingIsEnthusiastic
        let size = enthusiastic ? NSSize(width: 110, height: 28) : NSSize(width: 40, height: 22)
        var origin = NSPoint(
            x: rect.maxX - size.width - 8,
            y: min(bounds.maxY - size.height - 4, rect.maxY - 18)
        )
        origin.x = min(max(bounds.minX + 6, origin.x), bounds.maxX - size.width - 6)
        origin.y = min(max(bounds.minY + 58, origin.y), bounds.maxY - size.height - 4)

        let bubble = NSRect(origin: origin, size: size)
        let outline = NSColor(calibratedRed: 0.07, green: 0.16, blue: 0.36, alpha: 0.92)
        let fill = NSColor.white.withAlphaComponent(0.96)

        outline.setFill()
        bubble.fill()
        NSRect(x: bubble.minX + 8, y: bubble.minY - 4, width: 8, height: 4).fill()
        NSRect(x: bubble.minX + 10, y: bubble.minY - 8, width: 4, height: 4).fill()

        fill.setFill()
        bubble.insetBy(dx: 2, dy: 2).fill()
        NSRect(x: bubble.minX + 10, y: bubble.minY - 2, width: 4, height: 4).fill()

        if enthusiastic {
            drawGreetingHelpText(in: bubble.insetBy(dx: 7, dy: 7), color: statusColor)
        } else {
            drawPixelGreetingText(
                x: bubble.minX + 10,
                y: bubble.minY + 6,
                scale: 2,
                color: statusColor.withAlphaComponent(0.66)
            )
        }
    }

    private var greetingIsEnthusiastic: Bool {
        let elapsed = greetingElapsedTicks
        if greetingWasFromSleep {
            return elapsed >= 98
        }
        if greetingWasFromRest {
            return elapsed >= 66
        }
        return elapsed >= 24
    }

    private func drawGreetingHelpText(in rect: NSRect, color: NSColor) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byClipping

        ("how can I help?" as NSString).draw(
            in: rect,
            withAttributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 8.5, weight: .semibold),
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
        )
    }

    private func drawPixelGreetingText(x: CGFloat, y: CGFloat, scale: CGFloat, color: NSColor) {
        let h = ["101", "101", "111", "101", "101"]
        let i = ["111", "010", "010", "010", "111"]

        drawPixelPattern(h, x: x, y: y, scale: scale, color: color)
        drawPixelPattern(i, x: x + 8, y: y, scale: scale, color: color)
    }

    private func drawPixelPattern(_ pattern: [String], x: CGFloat, y: CGFloat, scale: CGFloat, color: NSColor) {
        for (rowIndex, row) in pattern.enumerated() {
            for (columnIndex, cell) in Array(row).enumerated() where cell == "1" {
                drawPixelSquare(
                    x: x + CGFloat(columnIndex) * scale,
                    y: y + CGFloat(pattern.count - rowIndex - 1) * scale,
                    size: scale,
                    color: color
                )
            }
        }
    }

    private func drawPixelSquare(x: CGFloat, y: CGFloat, size: CGFloat, color: NSColor) {
        color.setFill()
        NSRect(
            x: round(x),
            y: round(y),
            width: size,
            height: size
        ).fill()
    }

    private var statusColor: NSColor {
        switch mood {
        case .idle:
            return NSColor(calibratedRed: 0.25, green: 0.48, blue: 0.94, alpha: 1)
        case .listening:
            return NSColor(calibratedRed: 0.32, green: 0.70, blue: 0.96, alpha: 1)
        case .reading:
            return NSColor(calibratedRed: 0.28, green: 0.78, blue: 0.72, alpha: 1)
        case .thinking:
            return NSColor(calibratedRed: 0.58, green: 0.58, blue: 0.96, alpha: 1)
        case .threadActive:
            return NSColor(calibratedRed: 0.36, green: 0.74, blue: 0.98, alpha: 1)
        case .working:
            return NSColor(calibratedRed: 0.96, green: 0.60, blue: 0.20, alpha: 1)
        case .success:
            return NSColor(calibratedRed: 0.29, green: 0.72, blue: 0.42, alpha: 1)
        case .failed:
            return NSColor(calibratedRed: 0.90, green: 0.22, blue: 0.26, alpha: 1)
        }
    }

    private func drawPixelShadow(pixel: CGFloat, origin: NSPoint) {
        let shadow = NSColor.black.withAlphaComponent(0.16)
        drawBlock(x: 4, y: 0, width: 9, height: 1, pixel: pixel, origin: origin, color: shadow)
        drawBlock(x: 5, y: -1, width: 7, height: 1, pixel: pixel, origin: origin, color: shadow.withAlphaComponent(0.10))
    }

    private func drawPixelSprite(pixel: CGFloat, origin: NSPoint, stepFrame: Bool, blink: Bool, pulse: Bool) {
        let outline = NSColor(calibratedRed: 0.10, green: 0.13, blue: 0.16, alpha: 1)
        let hair = NSColor(calibratedRed: 0.20, green: 0.17, blue: 0.30, alpha: 1)
        let hairLight = NSColor(calibratedRed: 0.35, green: 0.28, blue: 0.52, alpha: 1)
        let skin = NSColor(calibratedRed: 0.98, green: 0.77, blue: 0.57, alpha: 1)
        let skinShadow = NSColor(calibratedRed: 0.90, green: 0.61, blue: 0.45, alpha: 1)
        let cheek = NSColor(calibratedRed: 0.98, green: 0.42, blue: 0.49, alpha: 1)
        let hoodie = NSColor(calibratedRed: 0.14, green: 0.64, blue: 0.72, alpha: 1)
        let hoodieLight = NSColor(calibratedRed: 0.35, green: 0.84, blue: 0.86, alpha: 1)
        let hoodieDark = NSColor(calibratedRed: 0.08, green: 0.42, blue: 0.51, alpha: 1)
        let pants = NSColor(calibratedRed: 0.21, green: 0.26, blue: 0.39, alpha: 1)
        let eye = NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.12, alpha: 1)
        let shine = NSColor.white.withAlphaComponent(0.95)

        // A tiny pixel-person companion: hair, face, hoodie, arms, and feet.
        drawSparkles(pixel: pixel, origin: origin, pulse: pulse)

        // Tiny legs and shoes under an oversized chibi head.
        drawBlock(x: 7, y: 2, width: 1, height: 2, pixel: pixel, origin: origin, color: pants)
        drawBlock(x: 10, y: 2, width: 1, height: 2, pixel: pixel, origin: origin, color: pants)
        drawBlock(x: stepFrame ? 5 : 6, y: 1, width: 3, height: 1, pixel: pixel, origin: origin, color: outline)
        drawBlock(x: stepFrame ? 10 : 9, y: 1, width: 3, height: 1, pixel: pixel, origin: origin, color: outline)

        // Tiny hoodie body.
        drawBlock(x: 6, y: 4, width: 6, height: 1, pixel: pixel, origin: origin, color: outline)
        drawBlock(x: 5, y: 5, width: 8, height: 4, pixel: pixel, origin: origin, color: outline)
        drawBlock(x: 6, y: 5, width: 6, height: 4, pixel: pixel, origin: origin, color: hoodie)
        drawBlock(x: 6, y: 8, width: 6, height: 1, pixel: pixel, origin: origin, color: hoodieLight)
        drawBlock(x: 10, y: 5, width: 2, height: 3, pixel: pixel, origin: origin, color: hoodieDark)
        drawBlock(x: 8, y: 6, width: 2, height: 1, pixel: pixel, origin: origin, color: outline.withAlphaComponent(0.55))
        drawBlock(x: 8, y: 7, width: 1, height: 1, pixel: pixel, origin: origin, color: statusColor)
        drawBlock(x: 9, y: 7, width: 1, height: 1, pixel: pixel, origin: origin, color: pulse ? statusColor : statusColor.withAlphaComponent(0.55))

        // Arms. One side waves while idle/success.
        drawBlock(x: 4, y: 5, width: 1, height: 3, pixel: pixel, origin: origin, color: outline)
        drawBlock(x: 3, y: 4, width: 2, height: 1, pixel: pixel, origin: origin, color: skin)
        let waving = mood == .idle || mood == .success
        drawBlock(x: 13, y: waving && stepFrame ? 7 : 5, width: 1, height: 3, pixel: pixel, origin: origin, color: outline)
        drawBlock(x: 14, y: waving && stepFrame ? 9 : 4, width: 2, height: 1, pixel: pixel, origin: origin, color: skin)

        // Oversized chibi head and soft hair mass.
        drawBlock(x: 5, y: 8, width: 8, height: 1, pixel: pixel, origin: origin, color: outline)
        drawBlock(x: 4, y: 9, width: 10, height: 7, pixel: pixel, origin: origin, color: outline)
        drawBlock(x: 5, y: 16, width: 8, height: 2, pixel: pixel, origin: origin, color: outline)
        drawBlock(x: 5, y: 9, width: 8, height: 7, pixel: pixel, origin: origin, color: skin)
        drawBlock(x: 11, y: 9, width: 2, height: 6, pixel: pixel, origin: origin, color: skinShadow.withAlphaComponent(0.38))

        // Chunky hair cap, side locks, and rounded bangs.
        drawBlock(x: 5, y: 15, width: 8, height: 3, pixel: pixel, origin: origin, color: hair)
        drawBlock(x: 4, y: 12, width: 2, height: 4, pixel: pixel, origin: origin, color: hair)
        drawBlock(x: 12, y: 12, width: 2, height: 4, pixel: pixel, origin: origin, color: hair)
        drawBlock(x: 6, y: 14, width: 2, height: 3, pixel: pixel, origin: origin, color: hairLight)
        drawBlock(x: 8, y: 13, width: 1, height: 3, pixel: pixel, origin: origin, color: hair)
        drawBlock(x: 10, y: 14, width: 2, height: 2, pixel: pixel, origin: origin, color: hair)
        drawBlock(x: 7, y: 12, width: 1, height: 2, pixel: pixel, origin: origin, color: hair)

        drawPersonFace(pixel: pixel, origin: origin, blink: blink, eye: eye, shine: shine, cheek: cheek)

        if mood == .success {
            drawBlock(x: 1, y: 14, width: 1, height: 1, pixel: pixel, origin: origin, color: statusColor)
            drawBlock(x: 3, y: 16, width: 1, height: 1, pixel: pixel, origin: origin, color: statusColor.withAlphaComponent(0.75))
        }
    }

    private func drawPersonFace(
        pixel: CGFloat,
        origin: NSPoint,
        blink: Bool,
        eye: NSColor,
        shine: NSColor,
        cheek: NSColor
    ) {
        drawBlock(x: 5, y: 12, width: 1, height: 1, pixel: pixel, origin: origin, color: cheek.withAlphaComponent(0.72))
        drawBlock(x: 12, y: 12, width: 1, height: 1, pixel: pixel, origin: origin, color: cheek.withAlphaComponent(0.58))

        switch mood {
        case .idle, .listening, .reading, .thinking, .threadActive:
            drawOpenPersonEyes(pixel: pixel, origin: origin, blink: blink, eye: eye, shine: shine)
            drawTinySmile(pixel: pixel, origin: origin, eye: eye)

        case .working:
            drawBlock(x: 6, y: 14, width: 2, height: 1, pixel: pixel, origin: origin, color: eye.withAlphaComponent(0.75))
            drawBlock(x: 10, y: 14, width: 2, height: 1, pixel: pixel, origin: origin, color: eye.withAlphaComponent(0.75))
            drawOpenPersonEyes(pixel: pixel, origin: origin, blink: blink, eye: eye, shine: shine)
            drawBlock(x: 7, y: 12, width: 4, height: 1, pixel: pixel, origin: origin, color: eye)
            drawBlock(x: 13, y: 15, width: 1, height: 1, pixel: pixel, origin: origin, color: statusColor)

        case .success:
            drawHappyPersonEyes(pixel: pixel, origin: origin, blink: blink, eye: eye)
            drawBlock(x: 7, y: 12, width: 1, height: 1, pixel: pixel, origin: origin, color: eye)
            drawBlock(x: 10, y: 12, width: 1, height: 1, pixel: pixel, origin: origin, color: eye)
            drawBlock(x: 8, y: 11, width: 2, height: 1, pixel: pixel, origin: origin, color: eye)
            drawBlock(x: 8, y: 10, width: 2, height: 1, pixel: pixel, origin: origin, color: NSColor.white.withAlphaComponent(0.70))

        case .failed:
            drawWorriedPersonEyes(pixel: pixel, origin: origin, eye: eye)
            drawBlock(x: 7, y: 12, width: 4, height: 1, pixel: pixel, origin: origin, color: eye)
            drawBlock(x: 7, y: 11, width: 1, height: 1, pixel: pixel, origin: origin, color: eye)
            drawBlock(x: 10, y: 11, width: 1, height: 1, pixel: pixel, origin: origin, color: eye)
        }
    }

    private func drawOpenPersonEyes(pixel: CGFloat, origin: NSPoint, blink: Bool, eye: NSColor, shine: NSColor) {
        if blink {
            drawBlock(x: 6, y: 13, width: 2, height: 1, pixel: pixel, origin: origin, color: eye)
            drawBlock(x: 10, y: 13, width: 2, height: 1, pixel: pixel, origin: origin, color: eye)
            return
        }

        drawBlock(x: 6, y: 13, width: 2, height: 2, pixel: pixel, origin: origin, color: eye)
        drawBlock(x: 10, y: 13, width: 2, height: 2, pixel: pixel, origin: origin, color: eye)
        drawBlock(x: 7, y: 14, width: 1, height: 1, pixel: pixel, origin: origin, color: shine)
        drawBlock(x: 11, y: 14, width: 1, height: 1, pixel: pixel, origin: origin, color: shine.withAlphaComponent(0.85))
    }

    private func drawHappyPersonEyes(pixel: CGFloat, origin: NSPoint, blink: Bool, eye: NSColor) {
        if blink {
            drawBlock(x: 6, y: 13, width: 2, height: 1, pixel: pixel, origin: origin, color: eye)
            drawBlock(x: 10, y: 13, width: 2, height: 1, pixel: pixel, origin: origin, color: eye)
            return
        }

        drawBlock(x: 6, y: 14, width: 1, height: 1, pixel: pixel, origin: origin, color: eye)
        drawBlock(x: 7, y: 13, width: 1, height: 1, pixel: pixel, origin: origin, color: eye)
        drawBlock(x: 10, y: 13, width: 1, height: 1, pixel: pixel, origin: origin, color: eye)
        drawBlock(x: 11, y: 14, width: 1, height: 1, pixel: pixel, origin: origin, color: eye)
    }

    private func drawWorriedPersonEyes(pixel: CGFloat, origin: NSPoint, eye: NSColor) {
        drawBlock(x: 6, y: 14, width: 2, height: 1, pixel: pixel, origin: origin, color: eye)
        drawBlock(x: 10, y: 14, width: 2, height: 1, pixel: pixel, origin: origin, color: eye)
        drawBlock(x: 7, y: 13, width: 1, height: 1, pixel: pixel, origin: origin, color: eye)
        drawBlock(x: 10, y: 13, width: 1, height: 1, pixel: pixel, origin: origin, color: eye)
    }

    private func drawTinySmile(pixel: CGFloat, origin: NSPoint, eye: NSColor) {
        drawBlock(x: 7, y: 12, width: 1, height: 1, pixel: pixel, origin: origin, color: eye)
        drawBlock(x: 8, y: 11, width: 2, height: 1, pixel: pixel, origin: origin, color: eye)
        drawBlock(x: 10, y: 12, width: 1, height: 1, pixel: pixel, origin: origin, color: eye)
    }

    private func drawSparkles(pixel: CGFloat, origin: NSPoint, pulse: Bool) {
        let sparkle = pulse ? statusColor : statusColor.withAlphaComponent(0.45)
        drawBlock(x: 3, y: 16, width: 1, height: 1, pixel: pixel, origin: origin, color: sparkle)
        drawBlock(x: 15, y: 14, width: 1, height: 1, pixel: pixel, origin: origin, color: sparkle.withAlphaComponent(0.65))
    }

    private func drawBlock(
        x: Int,
        y: Int,
        width: Int,
        height: Int,
        pixel: CGFloat,
        origin: NSPoint,
        color: NSColor
    ) {
        color.setFill()
        NSRect(
            x: origin.x + CGFloat(x) * pixel,
            y: origin.y + CGFloat(y) * pixel,
            width: CGFloat(width) * pixel,
            height: CGFloat(height) * pixel
        ).fill()
    }
}
