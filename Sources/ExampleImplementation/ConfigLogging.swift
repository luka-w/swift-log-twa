//
// THIS IS NOT PART OF THE PITCH, JUST AN EXAMPLE HOW A LOGGER IMPLEMENTATION LOOKS LIKE
//

import Foundation
import Logging

// this is a contrived example of a logging library implementation that allows users to define log levels per logger label
// this example uses a simplistic in-memory config which can be changed at runtime via code
// real implementations could use external config files that can be changed outside the running program
public final class ConfigLogging {
    public var config = Config(defaultLogLevel: LogLevel.info)

    public init() {}

    public func make(label: String) -> LogHandler {
        return Logger(label: label, config: self.config)
    }

    private struct Logger: LogHandler {
        private var logger: SimpleLogger
        private var config: Config

        public init(label: String, config: Config) {
            self.logger = SimpleLogger(label: label)
            self.config = config
        }

        public func log(level: LogLevel, message: String, file _: String, function _: String, line _: UInt) {
            self.logger.log(level: level, message: message) { text in
                print(text)
            }
        }

        public var logLevel: LogLevel {
            get { return self.logger.logLevel ?? self.config.get(key: self.logger.label) }
            set { self.logger.logLevel = newValue }
        }

        public var metadata: LoggingMetadata? {
            get { return self.logger.metadata }
            set { self.logger.metadata = newValue }
        }

        public subscript(metadataKey metadataKey: String) -> String? {
            get { return self.logger[metadataKey: metadataKey] }
            set { self.logger[metadataKey: metadataKey] = newValue }
        }
    }

    public class Config {
        private static let ALL = "*"

        private let lock = NSLock()
        private var storage = [String: LogLevel]()
        private var defaultLogLevel: LogLevel

        init(defaultLogLevel: LogLevel) {
            self.defaultLogLevel = defaultLogLevel
        }

        func get(key: String) -> LogLevel {
            return self.get(key) ?? self.get(Config.ALL) ?? self.defaultLogLevel
        }

        func get(_ key: String) -> LogLevel? {
            return self.lock.withLock { self.storage[key] }
        }

        public func set(key: String, value: LogLevel) {
            self.lock.withLock { self.storage[key] = value }
        }

        public func set(value: LogLevel) {
            self.lock.withLock { self.storage[Config.ALL] = value }
        }

        public func clear() {
            self.lock.withLock { self.storage.removeAll() }
        }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        self.lock()
        defer {
            self.unlock()
        }
        return body()
    }
}
