//
//  GameScene.swift
//  FindNumber
//
//  Created by Jukchai Sengboonleng on 15/10/26.
//

import SpriteKit
import UIKit
import AVFoundation

final class GameScene: SKScene {
    var onGameCompletionChanged: ((Bool) -> Void)?

    private let background = SKColor(red: 0.04, green: 0.07, blue: 0.12, alpha: 1)
    private let tileColor = SKColor(red: 0.09, green: 0.14, blue: 0.21, alpha: 1)
    private let tileBorderColor = SKColor(red: 0.18, green: 0.24, blue: 0.33, alpha: 1)
    private let completedColor = SKColor(red: 0.10, green: 0.32, blue: 0.24, alpha: 1)
    private let completedTextColor = SKColor(red: 0.58, green: 0.91, blue: 0.71, alpha: 1)
    private let supportedDimensions = [5, 7, 10]
    private let bestTimesKey = "findNumber.bestTimes"

    private var selectedDimension: Int?
    private var showingHistory = false
    private var numbers: [Int] = []
    private var tiles: [Int: SKShapeNode] = [:]
    private var timerLabel: SKLabelNode?
    private var instructionLabel: SKLabelNode?
    private var nextNumber = 1
    private var completedNumbers: Set<Int> = []
    private var startedAt: TimeInterval = 0
    private var elapsedTime: TimeInterval = 0
    private var isFinished = false
    private var isNewRecord = false
    private var hasAppeared = false
    private var safeAreaInsets = UIEdgeInsets.zero
    private var soundPlayers: [String: AVAudioPlayer] = [:]
    private var hasPreloadedSounds = false

    override func didMove(to view: SKView) {
        safeAreaInsets = view.safeAreaInsets
        hasAppeared = true
        preloadSounds()
        showDimensionPicker()
    }

    func updateSafeAreaInsets(_ insets: UIEdgeInsets) {
        guard safeAreaInsets != insets else { return }
        safeAreaInsets = insets
        if hasAppeared {
            layoutScreen()
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard hasAppeared else { return }
        layoutScreen()
    }

    override func update(_ currentTime: TimeInterval) {
        guard !isFinished, selectedDimension != nil, startedAt > 0 else { return }
        elapsedTime = ProcessInfo.processInfo.systemUptime - startedAt
        timerLabel?.text = formattedTime(elapsedTime)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let tappedNodes = nodes(at: location)

        if let dimension = tappedNodes.compactMap({ node -> Int? in
            guard let name = node.name, name.hasPrefix("dimension-") else { return nil }
            return Int(name.dropFirst("dimension-".count))
        }).first, supportedDimensions.contains(dimension) {
            selectedDimension = dimension
            startNewGame()
            return
        }

        if tappedNodes.contains(where: { $0.name == "select-dimension" }) {
            showDimensionPicker()
            return
        }

        if tappedNodes.contains(where: { $0.name == "history-button" }) {
            showingHistory = true
            selectedDimension = nil
            startedAt = 0
            isFinished = false
            isNewRecord = false
            onGameCompletionChanged?(false)
            layoutScreen()
            return
        }

        if tappedNodes.contains(where: { $0.name == "history-back-button" }) {
            showDimensionPicker()
            return
        }

        if tappedNodes.contains(where: {
            $0.name == "restart-button" || $0.parent?.name == "restart-button"
        }) {
            showDimensionPicker()
            return
        }

        guard selectedDimension != nil else { return }
        if isFinished {
            startNewGame()
            return
        }

        guard let cellName = tappedNodes.compactMap({ node -> String? in
            if let name = node.name, name.hasPrefix("cell-") {
                return name
            }
            if let name = node.parent?.name, name.hasPrefix("cell-") {
                return name
            }
            return nil
        }).first,
        let number = Int(cellName.dropFirst("cell-".count)),
        let tile = tiles[number] else {
            return
        }

        guard number == nextNumber else {
            playSound(named: "wrong-number.wav")
            flashIncorrectSelection(on: tile)
            return
        }

        playSound(named: "number-click.wav")
        tile.removeAction(forKey: "incorrect")
        completedNumbers.insert(number)
        tile.fillColor = completedColor
        tile.strokeColor = completedColor
        tile.children.compactMap { $0 as? SKLabelNode }.first?.fontColor = completedTextColor
        tile.name = nil
        nextNumber += 1
        instructionLabel?.text = nextNumber <= numbers.count ? "Find \(nextNumber)" : "Complete"

        if nextNumber > numbers.count {
            finishGame()
        }
    }

    private func showDimensionPicker() {
        showingHistory = false
        selectedDimension = nil
        startedAt = 0
        isFinished = false
        isNewRecord = false
        onGameCompletionChanged?(false)
        layoutScreen()
    }

    private func startNewGame() {
        guard let dimension = selectedDimension else { return }
        showingHistory = false
        numbers = Array(1...(dimension * dimension)).shuffled()
        tiles.removeAll()
        completedNumbers.removeAll()
        nextNumber = 1
        elapsedTime = 0
        isFinished = false
        isNewRecord = false
        startedAt = ProcessInfo.processInfo.systemUptime
        onGameCompletionChanged?(false)
        layoutScreen()
    }

    private func layoutScreen() {
        guard hasAppeared else { return }
        removeAllChildren()
        backgroundColor = background
        tiles.removeAll()

        if showingHistory {
            layoutHistory()
            return
        }

        guard let dimension = selectedDimension else {
            layoutDimensionPicker()
            return
        }
        layoutGame(dimension: dimension)
    }

    private func layoutDimensionPicker() {
        let safeTop = size.height - safeAreaInsets.top
        let safeBottom = safeAreaInsets.bottom
        let availableHeight = max(0, safeTop - safeBottom)
        let centerY = safeBottom + availableHeight / 2
        let titleFontSize = min(38, max(28, size.width * 0.09))

        let title = makeLabel(
            "Find Number",
            font: "AvenirNext-Bold",
            size: titleFontSize,
            color: .white
        )
        title.position = CGPoint(x: size.width / 2, y: centerY + min(150, availableHeight * 0.25))
        addChild(title)

        let iconSize = min(80, max(56, availableHeight * 0.12))
        let gameIcon = SKSpriteNode(imageNamed: "GameIcon")
        gameIcon.size = CGSize(width: iconSize, height: iconSize)
        gameIcon.position = CGPoint(
            x: size.width / 2,
            y: title.position.y + titleFontSize / 2 + 12 + iconSize / 2
        )
        addChild(gameIcon)

        let subtitle = makeLabel(
            "Choose a board size",
            font: "AvenirNext-Medium",
            size: 17,
            color: SKColor(red: 0.62, green: 0.70, blue: 0.81, alpha: 1)
        )
        subtitle.position = CGPoint(x: size.width / 2, y: title.position.y - 40)
        addChild(subtitle)

        let buttonWidth = min(size.width - 48, 360)
        let isLandscape = size.width > size.height
        let buttonHeight: CGFloat = isLandscape ? 76 : 72
        let spacing: CGFloat = isLandscape ? 20 : 16
        let totalHeight = CGFloat(supportedDimensions.count) * buttonHeight
            + CGFloat(supportedDimensions.count - 1) * spacing
        let buttonsCenterY = centerY - 35
        let firstButtonY = buttonsCenterY + totalHeight / 2 - buttonHeight / 2

        for (index, dimension) in supportedDimensions.enumerated() {
            let position: CGPoint
            let buttonSize: CGSize
            if isLandscape {
                buttonSize = CGSize(
                    width: min((size.width - 64 - spacing * 2) / 3, 260),
                    height: buttonHeight
                )
                position = CGPoint(
                    x: size.width / 2 + CGFloat(index - 1) * (buttonSize.width + spacing),
                    y: buttonsCenterY
                )
            } else {
                buttonSize = CGSize(width: buttonWidth, height: buttonHeight)
                position = CGPoint(
                    x: size.width / 2,
                    y: firstButtonY - CGFloat(index) * (buttonHeight + spacing)
                )
            }

            let button = SKShapeNode(
                rectOf: buttonSize,
                cornerRadius: 18
            )
            button.name = "dimension-\(dimension)"
            button.position = position
            button.fillColor = tileColor
            button.strokeColor = tileBorderColor
            button.lineWidth = 1

            let label = makeLabel(
                "\(dimension) × \(dimension)",
                font: "AvenirNext-DemiBold",
                size: 23,
                color: .white
            )
            button.addChild(label)
            addChild(button)
        }

        let historyButton = makeButton(
            title: "History",
            name: "history-button",
            size: CGSize(width: 142, height: 48),
            fontSize: 17
        )
        historyButton.position = CGPoint(
            x: safeAreaInsets.left + 88,
            y: safeAreaInsets.bottom + 40
        )
        addChild(historyButton)
    }

    private func layoutHistory() {
        let safeTop = size.height - safeAreaInsets.top
        let safeBottom = safeAreaInsets.bottom
        let centerY = safeBottom + max(0, safeTop - safeBottom) / 2

        let title = makeLabel("Best Times", font: "AvenirNext-Bold", size: 34, color: .white)
        title.position = CGPoint(x: size.width / 2, y: centerY + 130)
        addChild(title)

        let savedTimes = UserDefaults.standard.dictionary(forKey: bestTimesKey) as? [String: Double] ?? [:]
        for (index, dimension) in supportedDimensions.enumerated() {
            let key = dimensionKey(dimension)
            let bestTime = savedTimes[key].map(formattedTime) ?? "--:--.--"
            let rowY = centerY + 55 - CGFloat(index) * 68
            let row = SKShapeNode(
                rectOf: CGSize(width: min(size.width - 48, 360), height: 54),
                cornerRadius: 14
            )
            row.fillColor = tileColor
            row.strokeColor = tileBorderColor
            row.lineWidth = 1
            row.position = CGPoint(x: size.width / 2, y: rowY)

            let dimensionLabel = makeLabel(
                "\(dimension) × \(dimension)",
                font: "AvenirNext-DemiBold",
                size: 18,
                color: .white
            )
            dimensionLabel.horizontalAlignmentMode = .left
            dimensionLabel.position = CGPoint(x: -min(size.width - 48, 360) / 2 + 20, y: 0)
            row.addChild(dimensionLabel)

            let timeLabel = makeLabel(
                bestTime,
                font: "AvenirNext-Bold",
                size: 18,
                color: completedTextColor
            )
            timeLabel.horizontalAlignmentMode = .right
            timeLabel.position = CGPoint(x: min(size.width - 48, 360) / 2 - 20, y: 0)
            row.addChild(timeLabel)
            addChild(row)
        }

        let backButton = makeButton(
            title: "Back",
            name: "history-back-button",
            size: CGSize(width: 160, height: 50),
            fontSize: 18
        )
        backButton.position = CGPoint(x: size.width / 2, y: safeBottom + 48)
        addChild(backButton)
    }

    private func makeButton(
        title: String,
        name: String,
        size: CGSize,
        fontSize: CGFloat
    ) -> SKShapeNode {
        let button = SKShapeNode(
            rectOf: size,
            cornerRadius: 16
        )
        button.name = name
        button.fillColor = tileColor
        button.strokeColor = tileBorderColor
        button.lineWidth = 1

        let label = makeLabel(title, font: "AvenirNext-DemiBold", size: fontSize, color: .white)
        button.addChild(label)
        return button
    }

    private func layoutGame(dimension: Int) {
        let timerY = size.height - safeAreaInsets.top - 38
        let instructionY = timerY - 54

        let timer = makeLabel(
            formattedTime(elapsedTime),
            font: "AvenirNext-DemiBold",
            size: 28,
            color: .white
        )
        timer.position = CGPoint(x: size.width / 2, y: timerY)
        addChild(timer)
        timerLabel = timer

        let instruction = makeLabel(
            isFinished ? "Great job!" : "Find \(nextNumber)",
            font: "AvenirNext-Bold",
            size: min(25, max(21, size.width * 0.065)),
            color: completedTextColor
        )
        let instructionBox = SKShapeNode(
            rectOf: CGSize(width: min(size.width - 48, 190), height: 48),
            cornerRadius: 16
        )
        instructionBox.fillColor = SKColor(red: 0.08, green: 0.15, blue: 0.18, alpha: 1)
        instructionBox.strokeColor = SKColor(red: 0.16, green: 0.38, blue: 0.30, alpha: 1)
        instructionBox.lineWidth = 1
        instructionBox.position = CGPoint(x: size.width / 2, y: instructionY - 8)
        instructionBox.addChild(instruction)
        instructionLabel = instruction
        addChild(instructionBox)

        let restartButtonSize = CGSize(width: min(size.width - 48, 190), height: 48)
        let restartButtonY = safeAreaInsets.bottom + (isFinished ? 90 : 40)
        let restartButton = SKShapeNode(
            rectOf: restartButtonSize,
            cornerRadius: 16
        )
        restartButton.name = "restart-button"
        restartButton.fillColor = tileColor
        restartButton.strokeColor = tileBorderColor
        restartButton.lineWidth = 1
        restartButton.position = CGPoint(x: size.width / 2, y: restartButtonY)

        let restartLabel = makeLabel(
            "Restart",
            font: "AvenirNext-DemiBold",
            size: 17,
            color: .white
        )
        restartButton.addChild(restartLabel)
        addChild(restartButton)

        let bottom = restartButtonY + restartButtonSize.height / 2 + 16
        let gridAreaTop = instructionY - 34
        let gridAreaHeight = max(0, gridAreaTop - bottom)
        let gridDimension = min(size.width - 24, gridAreaHeight)
        let gap = dimension >= 10 ? CGFloat(2) : CGFloat(4)
        let cellDimension = (gridDimension - gap * CGFloat(dimension - 1)) / CGFloat(dimension)
        let gridCenter = CGPoint(
            x: size.width / 2,
            y: bottom + gridAreaHeight / 2
        )
        let gridTop = gridCenter.y + gridDimension / 2

        for (index, number) in numbers.enumerated() {
            let row = index / dimension
            let column = index % dimension
            let cell = SKShapeNode(
                rectOf: CGSize(width: cellDimension, height: cellDimension),
                cornerRadius: min(5, cellDimension * 0.16)
            )
            cell.name = "cell-\(number)"
            let isCompleted = completedNumbers.contains(number)
            cell.fillColor = isCompleted ? completedColor : tileColor
            cell.strokeColor = isCompleted ? completedColor : tileBorderColor
            cell.lineWidth = 0.75
            cell.position = CGPoint(
                x: gridCenter.x - gridDimension / 2 + cellDimension / 2
                    + CGFloat(column) * (cellDimension + gap),
                y: gridTop - cellDimension / 2
                    - CGFloat(row) * (cellDimension + gap)
            )

            let numberLabel = makeLabel(
                "\(number)",
                font: "AvenirNext-DemiBold",
                size: max(8, min(20, cellDimension * 0.44)),
                color: isCompleted
                    ? completedTextColor
                    : SKColor(red: 0.88, green: 0.92, blue: 0.97, alpha: 1)
            )
            cell.addChild(numberLabel)
            if isCompleted {
                cell.name = nil
            }

            addChild(cell)
            tiles[number] = cell
        }

        if isFinished {
            addCompletionOverlay()
        }
    }

    private func makeLabel(
        _ text: String,
        font: String,
        size: CGFloat,
        color: SKColor
    ) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: font)
        label.text = text
        label.fontSize = size
        label.fontColor = color
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        return label
    }

    private func flashIncorrectSelection(on tile: SKShapeNode) {
        let originalColor = tileBorderColor
        tile.removeAction(forKey: "incorrect")
        tile.run(
            .sequence([
                .run { tile.strokeColor = SKColor(red: 0.91, green: 0.34, blue: 0.36, alpha: 1) },
                .wait(forDuration: 0.18),
                .run { tile.strokeColor = originalColor }
            ]),
            withKey: "incorrect"
        )
    }

    private func playSound(named fileName: String) {
        guard let player = soundPlayers[fileName] else { return }
        player.currentTime = 0
        player.play()
    }

    private func preloadSounds() {
        guard !hasPreloadedSounds else { return }
        hasPreloadedSounds = true

        for fileName in ["number-click.wav", "wrong-number.wav", "win.wav"] {
            let resourceName = (fileName as NSString).deletingPathExtension
            let fileExtension = (fileName as NSString).pathExtension
            guard let url = Bundle.main.url(forResource: resourceName, withExtension: fileExtension) else {
                print("Unable to find sound effect: \(fileName)")
                continue
            }

            do {
                let player = try AVAudioPlayer(contentsOf: url)
                guard player.prepareToPlay() else {
                    print("Unable to prepare sound effect: \(fileName)")
                    continue
                }
                soundPlayers[fileName] = player
            } catch {
                print("Unable to load sound effect \(fileName): \(error.localizedDescription)")
            }
        }
    }

    private func finishGame() {
        isFinished = true
        elapsedTime = ProcessInfo.processInfo.systemUptime - startedAt
        isNewRecord = saveBestTime(elapsedTime, for: selectedDimension)
        playSound(named: "win.wav")
        onGameCompletionChanged?(true)
        layoutScreen()
    }

    private func saveBestTime(_ time: TimeInterval, for dimension: Int?) -> Bool {
        guard let dimension else { return false }
        var savedTimes = UserDefaults.standard.dictionary(forKey: bestTimesKey) as? [String: Double] ?? [:]
        let key = dimensionKey(dimension)
        if savedTimes[key].map({ time < $0 }) ?? true {
            savedTimes[key] = time
            UserDefaults.standard.set(savedTimes, forKey: bestTimesKey)
            return true
        }
        return false
    }

    private func dimensionKey(_ dimension: Int) -> String {
        "\(dimension)x\(dimension)"
    }

    private func addCompletionOverlay() {
        let panelSize = CGSize(width: min(size.width - 40, 320), height: 220)
        let panel = SKShapeNode(
            rectOf: panelSize,
            cornerRadius: 20
        )
        panel.name = "completion-panel"
        panel.fillColor = SKColor(red: 0.08, green: 0.12, blue: 0.19, alpha: 0.98)
        panel.strokeColor = tileBorderColor
        panel.lineWidth = 1
        panel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        panel.zPosition = 10

        let title = makeLabel(
            isNewRecord ? "New Record!" : "Finished!",
            font: "AvenirNext-DemiBold",
            size: 22,
            color: isNewRecord ? completedTextColor : .white
        )
        title.position = CGPoint(x: 0, y: 68)
        panel.addChild(title)

        let time = makeLabel(
            formattedTime(elapsedTime),
            font: "AvenirNext-Bold",
            size: 34,
            color: completedTextColor
        )
        time.position = CGPoint(x: 0, y: 26)
        panel.addChild(time)

        let replay = makeLabel(
            "Tap to play again",
            font: "AvenirNext-Medium",
            size: 14,
            color: SKColor(red: 0.62, green: 0.70, blue: 0.81, alpha: 1)
        )
        replay.name = "replay-game"
        replay.position = CGPoint(x: 0, y: -22)
        panel.addChild(replay)

        let selectSize = makeLabel(
            "Choose another size",
            font: "AvenirNext-Medium",
            size: 14,
            color: completedTextColor
        )
        selectSize.name = "select-dimension"
        selectSize.position = CGPoint(x: 0, y: -66)
        panel.addChild(selectSize)

        addChild(panel)
    }

    private func formattedTime(_ time: TimeInterval) -> String {
        let centiseconds = Int(time * 100)
        let minutes = centiseconds / 6_000
        let seconds = (centiseconds / 100) % 60
        let fraction = centiseconds % 100
        return String(format: "%02d:%02d.%02d", minutes, seconds, fraction)
    }
}
