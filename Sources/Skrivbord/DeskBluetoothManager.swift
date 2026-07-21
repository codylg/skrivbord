import CoreBluetooth
import Foundation
import os

private let logger = Logger(subsystem: "name.clg.Skrivbord", category: "bluetooth")

enum DeskConnectionState: Equatable {
    case bluetoothUnavailable(String)
    case disconnected
    case scanning
    case connecting
    case connected
}

@MainActor
final class DeskBluetoothManager: NSObject, ObservableObject {
    @Published private(set) var connectionState: DeskConnectionState = .disconnected
    @Published private(set) var currentHeightCM: Double?
    @Published private(set) var isMoving = false

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var commandCharacteristic: CBCharacteristic?
    private var heightCharacteristic: CBCharacteristic?
    private var moveTask: Task<Void, Never>?
    private var connectTimeoutTask: Task<Void, Never>?

    private let preferences: DeskPreferences

    private let resendInterval: TimeInterval = 0.25
    /// The desk keeps coasting for a bit after the last move command (motor
    /// momentum + Linak's own stop lag), so a tight tolerance here causes it
    /// to overshoot, reverse, overshoot the other way, and bounce a few times
    /// before settling. Widening the dead-band gives the coast distance room
    /// to land inside it without triggering a corrective reversal.
    private let toleranceCM: Double = 0.4
    private let moveSafetyTimeout: TimeInterval = 20
    private let connectTimeout: TimeInterval = 10
    /// If the desk moves opposite to the direction we just commanded by more
    /// than this in one tick, someone is manually overriding — yield to them
    /// instead of continuing to resend our original command.
    private let manualOverrideThresholdCM: Double = 0.3
    /// Minimum height change to count as "still moving" for stall detection.
    private let movementNoiseFloorCM: Double = 0.05
    /// If height notifications stop changing for this long after movement has
    /// already started, something is preventing the commanded move (typically
    /// a manual override that also stalls the height notifications rather
    /// than reversing them) — give up instead of continuing to resend for the
    /// full safety timeout.
    private let stallTimeout: TimeInterval = 1.0
    /// When a move starts (especially one that reverses the previous move's
    /// direction), the desk can still be coasting from the old command for a
    /// moment — that residual drift looks identical to a manual override.
    /// Suppress override/stall detection for this long at the start of each
    /// move so it doesn't mistake its own leftover momentum for interference.
    private let overrideDetectionGrace: TimeInterval = 0.75

    init(preferences: DeskPreferences) {
        self.preferences = preferences
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Public control surface

    func moveTo(heightCM target: Double) {
        guard connectionState == .connected else { return }
        let previousMoveTask = moveTask
        previousMoveTask?.cancel()
        isMoving = true
        let deadline = Date().addingTimeInterval(moveSafetyTimeout)
        moveTask = Task { [weak self] in
            // The previous task's cleanup (which unconditionally sends a
            // trailing stop command) isn't guaranteed to finish before this
            // task starts otherwise — that race could let the old stop land
            // right after this task's first move command, cancelling it out
            // and leaving the desk stopped in place instead of retargeting.
            await previousMoveTask?.value
            guard let self, !Task.isCancelled else { return }

            let moveStartTime = Date()
            var previousHeight = self.currentHeightCM
            var lastDirection: Double = 0
            var hasObservedMovement = false
            var stalledSince: Date?
            while !Task.isCancelled {
                guard let current = self.currentHeightCM else { break }
                if abs(target - current) <= self.toleranceCM { break }
                if Date() >= deadline { break }

                let pastGracePeriod = Date().timeIntervalSince(moveStartTime) >= self.overrideDetectionGrace
                if pastGracePeriod, let previous = previousHeight {
                    let observedDelta = current - previous
                    if lastDirection != 0 && observedDelta * lastDirection < -self.manualOverrideThresholdCM {
                        logger.debug("Manual override detected (moved opposite of commanded direction), yielding")
                        break
                    }
                    if abs(observedDelta) > self.movementNoiseFloorCM {
                        hasObservedMovement = true
                        stalledSince = nil
                    } else if hasObservedMovement {
                        let stallStart = stalledSince ?? Date()
                        stalledSince = stallStart
                        if Date().timeIntervalSince(stallStart) >= self.stallTimeout {
                            logger.debug("Height stopped changing for \(self.stallTimeout, format: .fixed(precision: 1))s mid-move, yielding (likely manual override)")
                            break
                        }
                    }
                }
                previousHeight = current

                lastDirection = target > current ? 1 : -1
                self.sendCommand(lastDirection > 0 ? LinakBLE.commandUp : LinakBLE.commandDown)
                try? await Task.sleep(nanoseconds: UInt64(self.resendInterval * 1_000_000_000))
            }
            self.sendCommand(LinakBLE.commandStop)
            self.isMoving = false
        }
    }

    // MARK: - Commands

    private func sendCommand(_ bytes: [UInt8]) {
        guard let peripheral, let commandCharacteristic else { return }
        let type: CBCharacteristicWriteType = commandCharacteristic.properties.contains(.writeWithoutResponse)
            ? .withoutResponse
            : .withResponse
        peripheral.writeValue(Data(bytes), for: commandCharacteristic, type: type)
    }

    private func stopMoving() {
        moveTask?.cancel()
        moveTask = nil
        isMoving = false
        sendCommand(LinakBLE.commandStop)
    }

    // MARK: - Connection lifecycle

    private func startScan() {
        guard central.state == .poweredOn else { return }
        logger.debug("Starting scan for service \(LinakBLE.serviceUUID)")
        connectionState = .scanning
        central.scanForPeripherals(withServices: [LinakBLE.serviceUUID], options: nil)
    }

    private func attemptReconnect() {
        guard let lastID = preferences.lastPeripheralID else {
            startScan()
            return
        }
        let known = central.retrievePeripherals(withIdentifiers: [lastID])
        if let match = known.first {
            logger.debug("Reconnecting to known peripheral \(lastID)")
            connect(to: match)
        } else {
            logger.debug("Known peripheral \(lastID) not retrievable, scanning instead")
            startScan()
        }
    }

    private func connect(to candidate: CBPeripheral) {
        connectionState = .connecting
        peripheral = candidate
        candidate.delegate = self
        central.connect(candidate, options: nil)

        connectTimeoutTask?.cancel()
        connectTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(self?.connectTimeout ?? 10) * 1_000_000_000)
            guard let self, !Task.isCancelled, self.connectionState != .connected else { return }
            logger.warning("Connect attempt to \(candidate.identifier) timed out after \(self.connectTimeout, format: .fixed(precision: 0))s")
            self.central.cancelPeripheralConnection(candidate)
            self.resetConnectionState()
            self.startScan()
        }
    }

    private func resetConnectionState() {
        connectTimeoutTask?.cancel()
        connectTimeoutTask = nil
        commandCharacteristic = nil
        heightCharacteristic = nil
        currentHeightCM = nil
        stopMoving()
        connectionState = .disconnected
    }
}

// MARK: - CBCentralManagerDelegate

extension DeskBluetoothManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            logger.debug("Central state updated: \(central.state.rawValue) (authorization: \(CBCentralManager.authorization.rawValue))")
            switch central.state {
            case .poweredOn:
                self.attemptReconnect()
            case .poweredOff:
                self.connectionState = .bluetoothUnavailable("Bluetooth is off — turn it on to connect.")
            case .unauthorized:
                self.connectionState = .bluetoothUnavailable(
                    "Bluetooth access denied — enable it in System Settings > Privacy & Security > Bluetooth."
                )
            case .unsupported:
                self.connectionState = .bluetoothUnavailable("This Mac doesn't support Bluetooth LE.")
            case .resetting, .unknown:
                self.connectionState = .disconnected
            @unknown default:
                self.connectionState = .disconnected
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        Task { @MainActor in
            logger.debug("Discovered peripheral \(peripheral.identifier) name=\(peripheral.name ?? "?") rssi=\(RSSI)")
            self.central.stopScan()
            self.connect(to: peripheral)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            logger.debug("didConnect \(peripheral.identifier), discovering services")
            self.preferences.lastPeripheralID = peripheral.identifier
            peripheral.discoverServices(nil)
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            logger.error("didFailToConnect \(peripheral.identifier): \(error?.localizedDescription ?? "no error")")
            self.resetConnectionState()
            self.startScan()
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            logger.debug("didDisconnectPeripheral \(peripheral.identifier): \(error?.localizedDescription ?? "no error")")
            self.resetConnectionState()
            self.startScan()
        }
    }
}

// MARK: - CBPeripheralDelegate

extension DeskBluetoothManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            logger.error("didDiscoverServices error: \(error.localizedDescription)")
            return
        }
        let services = peripheral.services ?? []
        logger.debug("didDiscoverServices: \(services.map { $0.uuid.uuidString })")
        // Discover characteristics broadly (not filtered) since the command and
        // height characteristics live under different service UUIDs than the
        // one advertised/scanned for — match by characteristic UUID instead.
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        if let error {
            logger.error("didDiscoverCharacteristicsFor \(service.uuid): \(error.localizedDescription)")
            return
        }
        let characteristics = service.characteristics ?? []
        Task { @MainActor in
            logger.debug("Service \(service.uuid) characteristics: \(characteristics.map { $0.uuid.uuidString })")
            for characteristic in characteristics {
                switch characteristic.uuid {
                case LinakBLE.commandCharacteristicUUID:
                    logger.debug("Found command characteristic")
                    self.commandCharacteristic = characteristic
                case LinakBLE.heightCharacteristicUUID:
                    logger.debug("Found height characteristic, subscribing")
                    self.heightCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                    peripheral.readValue(for: characteristic)
                default:
                    break
                }
            }
            if self.commandCharacteristic != nil && self.heightCharacteristic != nil {
                logger.debug("Both characteristics found, marking connected")
                self.connectTimeoutTask?.cancel()
                self.connectionState = .connected
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard characteristic.uuid == LinakBLE.heightCharacteristicUUID, let data = characteristic.value else { return }
        guard let heightCM = LinakBLE.heightCM(fromRawBytes: data) else { return }
        Task { @MainActor in
            self.currentHeightCM = heightCM
        }
    }
}
