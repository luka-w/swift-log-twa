//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Logging API open source project
//
// Copyright (c) 2018-2019 Apple Inc. and the Swift Logging API project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Logging API project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Darwin
#elseif os(Windows)
import CRT
#elseif canImport(Glibc)
import Glibc
#elseif canImport(WASILibc)
import WASILibc
#else
#error("Unsupported runtime")
#endif

import InstrumentationBaggage

/// A `Logger` is the central type in `SwiftLog`. Its central function is to emit log messages using one of the methods
/// corresponding to a log level.
///
/// `Logger`s are value types with respect to the ``logLevel`` and the ``metadata`` (as well as the immutable `label`
/// and the selected ``LogHandler``). Therefore, `Logger`s are suitable to be passed around between libraries if you want
/// to preserve metadata across libraries.
///
/// The most basic usage of a `Logger` is
///
/// ```swift
/// logger.info("Hello World!")
/// ```
public struct Logger {
    @usableFromInline
    var handler: LogHandler

    @usableFromInline
    var metadataProvider: MetadataProvider?

    /// An identifier of the creator of this `Logger`.
    public let label: String

    internal init(label: String, _ handler: LogHandler, metadataProvider: MetadataProvider?) {
        self.label = label
        self.handler = handler
        self.metadataProvider = metadataProvider
    }
}

extension Logger {
    /// Log a message passing the log level as a parameter.
    ///
    /// If the `logLevel` passed to this method is more severe than the `Logger`'s ``logLevel``, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - level: The log level to log `message` at. For the available log levels, see `Logger.Level`.
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message.
    ///    - source: The source this log messages originates from. Defaults
    ///              to the module emitting the log message (on Swift 5.3 or
    ///              newer and the folder name containing the log emitting file on Swift 5.2 or
    ///              older).
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#fileID` (on Swift 5.3 or newer and `#file` on Swift 5.2 or older).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    #if compiler(>=5.3)
    @inlinable
    public func log(level: Logger.Level,
                    _ message: @autoclosure () -> Logger.Message,
                    metadata: @autoclosure () -> Logger.Metadata? = nil,
                    source: @autoclosure () -> String? = nil,
                    file: String = #fileID, function: String = #function, line: UInt = #line) {
        if self.logLevel <= level {
            let taskLocalBaggage: Baggage?
            #if compiler(>=5.5) && canImport(_Concurrency)
            if #available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *), self.metadataProvider != nil {
                taskLocalBaggage = Baggage.current
            } else {
                taskLocalBaggage = nil
            }
            #else
            taskLocalBaggage = nil
            #endif
            let providerMetadata = self.metadataProvider?.metadata(taskLocalBaggage)
            let metadata: Metadata? = {
                guard let metadata = metadata(), !metadata.isEmpty else { return providerMetadata }
                guard let providerMetadata = providerMetadata else { return metadata }
                return providerMetadata.merging(metadata, uniquingKeysWith: { _, oneOffMetadata in oneOffMetadata })
            }()

            self.handler.log(level: level,
                             message: message(),
                             metadata: metadata,
                             source: source() ?? Logger.currentModule(fileID: (file)),
                             file: file, function: function, line: line)
        }
    }

    #else
    @inlinable
    public func log(level: Logger.Level,
                    _ message: @autoclosure () -> Logger.Message,
                    metadata: @autoclosure () -> Logger.Metadata? = nil,
                    source: @autoclosure () -> String? = nil,
                    file: String = #file, function: String = #function, line: UInt = #line) {
        if self.logLevel <= level {
            self.handler.log(level: level,
                             message: message(),
                             metadata: metadata(),
                             source: source() ?? Logger.currentModule(filePath: (file)),
                             file: file, function: function, line: line)
        }
    }
    #endif

    /// Log a message passing the log level as a parameter.
    ///
    /// If the `logLevel` passed to this method is more severe than the `Logger`'s ``logLevel``, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - level: The log level to log `message` at. For the available log levels, see `Logger.Level`.
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message.
    ///    - baggage: `Baggage` containing propagated runtime-generated metadata.
    ///    - source: The source this log messages originates from. Defaults
    ///              to the module emitting the log message (on Swift 5.3 or
    ///              newer and the folder name containing the log emitting file on Swift 5.2 or
    ///              older).
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#fileID` (on Swift 5.3 or newer and `#file` on Swift 5.2 or older).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    #if compiler(>=5.3)
    @inlinable
    public func log(level: Logger.Level,
                    _ message: @autoclosure () -> Logger.Message,
                    metadata: @autoclosure () -> Logger.Metadata? = nil,
                    baggage: Baggage?,
                    source: @autoclosure () -> String? = nil,
                    file: String = #fileID, function: String = #function, line: UInt = #line) {
        if self.logLevel <= level {
            let providerMetadata = self.metadataProvider?.metadata(baggage)
            let metadata: Metadata? = {
                guard let metadata = metadata(), !metadata.isEmpty else { return providerMetadata }
                guard let providerMetadata = providerMetadata else { return metadata }
                return providerMetadata.merging(metadata, uniquingKeysWith: { _, oneOffMetadata in oneOffMetadata })
            }()

            self.handler.log(level: level,
                             message: message(),
                             metadata: metadata,
                             source: source() ?? Logger.currentModule(fileID: (file)),
                             file: file, function: function, line: line)
        }
    }

    #else
    @inlinable
    public func log(level: Logger.Level,
                    _ message: @autoclosure () -> Logger.Message,
                    metadata: @autoclosure () -> Logger.Metadata? = nil,
                    baggage: Baggage?,
                    source: @autoclosure () -> String? = nil,
                    file: String = #file, function: String = #function, line: UInt = #line) {
        if self.logLevel <= level {
            let providerMetadata = self.metadataProvider?.metadata(baggage)
            let metadata: Metadata? = {
                guard let metadata = metadata(), !metadata.isEmpty else { return providerMetadata }
                guard let providerMetadata = providerMetadata else { return metadata }
                return providerMetadata.merging(metadata, uniquingKeysWith: { _, oneOffMetadata in oneOffMetadata })
            }()

            self.handler.log(level: level,
                             message: message(),
                             metadata: metadata,
                             source: source() ?? Logger.currentModule(filePath: (file)),
                             file: file, function: function, line: line)
        }
    }
    #endif

    /// Log a message passing the log level as a parameter.
    ///
    /// If the ``logLevel`` passed to this method is more severe than the `Logger`'s ``logLevel``, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - level: The log level to log `message` at. For the available log levels, see `Logger.Level`.
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message.
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#fileID` (on Swift 5.3 or newer and `#file` on Swift 5.2 or older).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    #if compiler(>=5.3)
    @inlinable
    public func log(level: Logger.Level,
                    _ message: @autoclosure () -> Logger.Message,
                    metadata: @autoclosure () -> Logger.Metadata? = nil,
                    file: String = #fileID, function: String = #function, line: UInt = #line) {
        self.log(level: level, message(), metadata: metadata(), source: nil, file: file, function: function, line: line)
    }

    #else
    @inlinable
    public func log(level: Logger.Level,
                    _ message: @autoclosure () -> Logger.Message,
                    metadata: @autoclosure () -> Logger.Metadata? = nil,
                    file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: level, message(), metadata: metadata(), source: nil, file: file, function: function, line: line)
    }
    #endif

    /// Add, change, or remove a logging metadata item.
    ///
    /// - note: Logging metadata behaves as a value that means a change to the logging metadata will only affect the
    ///         very `Logger` it was changed on.
    @inlinable
    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            return self.handler[metadataKey: metadataKey]
        }
        set {
            self.handler[metadataKey: metadataKey] = newValue
        }
    }

    /// Get or set the log level configured for this `Logger`.
    ///
    /// - note: `Logger`s treat `logLevel` as a value. This means that a change in `logLevel` will only affect this
    ///         very `Logger`. It is acceptable for logging backends to have some form of global log level override
    ///         that affects multiple or even all loggers. This means a change in `logLevel` to one `Logger` might in
    ///         certain cases have no effect.
    @inlinable
    public var logLevel: Logger.Level {
        get {
            return self.handler.logLevel
        }
        set {
            self.handler.logLevel = newValue
        }
    }
}

extension Logger {
    /// Log a message passing with the ``Logger/Level/trace`` log level.
    ///
    /// If `.trace` is at least as severe as the `Logger`'s ``logLevel``, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message
    ///    - baggage: `Baggage` containing propagated runtime-generated metadata.
    ///    - source: The source this log messages originates from. Defaults
    ///              to the module emitting the log message (on Swift 5.3 or
    ///              newer and the folder name containing the log emitting file on Swift 5.2 or
    ///              older).
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#fileID` (on Swift 5.3 or newer and `#file` on Swift 5.2 or older).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    #if compiler(>=5.3)
    @inlinable
    public func trace(_ message: @autoclosure () -> Logger.Message,
                      metadata: @autoclosure () -> Logger.Metadata? = nil,
                      baggage: Baggage?,
                      source: @autoclosure () -> String? = nil,
                      file: String = #fileID, function: String = #function, line: UInt = #line) {
        self.log(level: .trace, message(), metadata: metadata(), baggage: baggage, source: source(), file: file, function: function, line: line)
    }

    #else
    @inlinable
    public func trace(_ message: @autoclosure () -> Logger.Message,
                      metadata: @autoclosure () -> Logger.Metadata? = nil,
                      baggage: Baggage?,
                      source: @autoclosure () -> String? = nil,
                      file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: .trace, message(), metadata: metadata(), baggage: baggage, source: source(), file: file, function: function, line: line)
    }
    #endif

    /// Log a message passing with the ``Logger/Level/trace`` log level.
    ///
    /// If `.trace` is at least as severe as the `Logger`'s ``logLevel``, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message
    ///    - source: The source this log messages originates from. Defaults
    ///              to the module emitting the log message (on Swift 5.3 or
    ///              newer and the folder name containing the log emitting file on Swift 5.2 or
    ///              older).
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#fileID` (on Swift 5.3 or newer and `#file` on Swift 5.2 or older).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    #if compiler(>=5.3)
    @inlinable
    public func trace(_ message: @autoclosure () -> Logger.Message,
                      metadata: @autoclosure () -> Logger.Metadata? = nil,
                      source: @autoclosure () -> String? = nil,
                      file: String = #fileID, function: String = #function, line: UInt = #line) {
        self.log(level: .trace, message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
    }

    #else
    @inlinable
    public func trace(_ message: @autoclosure () -> Logger.Message,
                      metadata: @autoclosure () -> Logger.Metadata? = nil,
                      source: @autoclosure () -> String? = nil,
                      file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: .trace, message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
    }
    #endif

    /// Log a message passing with the ``Logger/Level/trace`` log level.
    ///
    /// If `.trace` is at least as severe as the `Logger`'s ``logLevel``, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message
    ///    - baggage: `Baggage` containing propagated runtime-generated metadata.
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#fileID` (on Swift 5.3 or newer and `#file` on Swift 5.2 or older).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    #if compiler(>=5.3)
    @inlinable
    public func trace(_ message: @autoclosure () -> Logger.Message,
                      metadata: @autoclosure () -> Logger.Metadata? = nil,
                      baggage: Baggage?,
                      file: String = #fileID, function: String = #function, line: UInt = #line) {
        self.trace(message(), metadata: metadata(), baggage: baggage, source: nil, file: file, function: function, line: line)
    }

    #else
    @inlinable
    public func trace(_ message: @autoclosure () -> Logger.Message,
                      metadata: @autoclosure () -> Logger.Metadata? = nil,
                      baggage: Baggage?,
                      file: String = #file, function: String = #function, line: UInt = #line) {
        self.trace(message(), metadata: metadata(), baggage: baggage, source: nil, file: file, function: function, line: line)
    }
    #endif

    /// Log a message passing with the ``Logger/Level/trace`` log level.
    ///
    /// If `.trace` is at least as severe as the `Logger`'s ``logLevel``, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#fileID` (on Swift 5.3 or newer and `#file` on Swift 5.2 or older).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    #if compiler(>=5.3)
    @inlinable
    public func trace(_ message: @autoclosure () -> Logger.Message,
                      metadata: @autoclosure () -> Logger.Metadata? = nil,
                      file: String = #fileID, function: String = #function, line: UInt = #line) {
        self.trace(message(), metadata: metadata(), source: nil, file: file, function: function, line: line)
    }

    #else
    @inlinable
    public func trace(_ message: @autoclosure () -> Logger.Message,
                      metadata: @autoclosure () -> Logger.Metadata? = nil,
                      file: String = #file, function: String = #function, line: UInt = #line) {
        self.trace(message(), metadata: metadata(), source: nil, file: file, function: function, line: line)
    }
    #endif

    /// Log a message passing with the ``Logger/Level/debug`` log level.
    ///
    /// If `.debug` is at least as severe as the `Logger`'s ``logLevel``, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message
    ///    - baggage: `Baggage` containing propagated runtime-generated metadata.
    ///    - source: The source this log messages originates from. Defaults
    ///              to the module emitting the log message (on Swift 5.3 or
    ///              newer and the folder name containing the log emitting file on Swift 5.2 or
    ///              older).
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#fileID` (on Swift 5.3 or newer and `#file` on Swift 5.2 or older).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    #if compiler(>=5.3)
    @inlinable
    public func debug(_ message: @autoclosure () -> Logger.Message,
                      metadata: @autoclosure () -> Logger.Metadata? = nil,
                      baggage: Baggage?,
                      source: @autoclosure () -> String? = nil,
                      file: String = #fileID, function: String = #function, line: UInt = #line) {
        self.log(level: .debug, message(), metadata: metadata(), baggage: baggage, source: source(), file: file, function: function, line: line)
    }

    #else
    @inlinable
    public func debug(_ message: @autoclosure () -> Logger.Message,
                      metadata: @autoclosure () -> Logger.Metadata? = nil,
                      baggage: Baggage?,
                      source: @autoclosure () -> String? = nil,
                      file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: .debug, message(), metadata: metadata(), baggage: baggage, source: source(), file: file, function: function, line: line)
    }
    #endif

    /// Log a message passing with the ``Logger/Level/debug`` log level.
    ///
    /// If `.debug` is at least as severe as the `Logger`'s ``logLevel``, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message
    ///    - source: The source this log messages originates from. Defaults
    ///              to the module emitting the log message (on Swift 5.3 or
    ///              newer and the folder name containing the log emitting file on Swift 5.2 or
    ///              older).
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#fileID` (on Swift 5.3 or newer and `#file` on Swift 5.2 or older).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    #if compiler(>=5.3)
    @inlinable
    public func debug(_ message: @autoclosure () -> Logger.Message,
                      metadata: @autoclosure () -> Logger.Metadata? = nil,
                      source: @autoclosure () -> String? = nil,
                      file: String = #fileID, function: String = #function, line: UInt = #line) {
        self.log(level: .debug, message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
    }

    #else
    @inlinable
    public func debug(_ message: @autoclosure () -> Logger.Message,
                      metadata: @autoclosure () -> Logger.Metadata? = nil,
                      source: @autoclosure () -> String? = nil,
                      file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: .debug, message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
    }
    #endif

    /// Log a message passing with the ``Logger/Level/debug`` log level.
    ///
    /// If `.debug` is at least as severe as the `Logger`'s ``logLevel``, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message
    ///    - baggage: `Baggage` containing propagated runtime-generated metadata.
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#fileID` (on Swift 5.3 or newer and `#file` on Swift 5.2 or older).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    #if compiler(>=5.3)
    @inlinable
    public func debug(_ message: @autoclosure () -> Logger.Message,
                      metadata: @autoclosure () -> Logger.Metadata? = nil,
                      baggage: Baggage?,
                      file: String = #fileID, function: String = #function, line: UInt = #line) {
        self.debug(message(), metadata: metadata(), baggage: baggage, source: nil, file: file, function: function, line: line)
    }

    #else
    @inlinable
    public func debug(_ message: @autoclosure () -> Logger.Message,
                      metadata: @autoclosure () -> Logger.Metadata? = nil,
                      baggage: Baggage?,
                      file: String = #file, function: String = #function, line: UInt = #line) {
        self.debug(message(), metadata: metadata(), baggage: baggage, source: nil, file: file, function: function, line: line)
    }
    #endif

    /// Log a message passing with the ``Logger/Level/debug`` log level.
    ///
    /// If `.debug` is at least as severe as the `Logger`'s ``logLevel``, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#fileID` (on Swift 5.3 or newer and `#file` on Swift 5.2 or older).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    #if compiler(>=5.3)
    @inlinable
    public func debug(_ message: @autoclosure () -> Logger.Message,
                      metadata: @autoclosure () -> Logger.Metadata? = nil,
                      file: String = #fileID, function: String = #function, line: UInt = #line) {
        self.debug(message(), metadata: metadata(), source: nil, file: file, function: function, line: line)
    }

    #else
    @inlinable
    public func debug(_ message: @autoclosure () -> Logger.Message,
                      metadata: @autoclosure () -> Logger.Metadata? = nil,
                      file: String = #file, function: String = #function, line: UInt = #line) {
        self.debug(message(), metadata: metadata(), source: nil, file: file, function: function, line: line)
    }
    #endif

    /// Log a message passing with the ``Logger/Level/info`` log level.
    ///
    /// If `.info` is at least as severe as the `Logger`'s ``logLevel``, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message
    ///    - baggage: `Baggage` containing propagated runtime-generated metadata.
    ///    - source: The source this log messages originates from. Defaults
    ///              to the module emitting the log message (on Swift 5.3 or
    ///              newer and the folder name containing the log emitting file on Swift 5.2 or
    ///              older).
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#fileID` (on Swift 5.3 or newer and `#file` on Swift 5.2 or older).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    #if compiler(>=5.3)
    @inlinable
    public func info(_ message: @autoclosure () -> Logger.Message,
                     metadata: @autoclosure () -> Logger.Metadata? = nil,
                     baggage: Baggage?,
                     source: @autoclosure () -> String? = nil,
                     file: String = #fileID, function: String = #function, line: UInt = #line) {
        self.log(level: .info, message(), metadata: metadata(), baggage: baggage, source: source(), file: file, function: function, line: line)
    }

    #else
    @inlinable
    public func info(_ message: @autoclosure () -> Logger.Message,
                     metadata: @autoclosure () -> Logger.Metadata? = nil,
                     baggage: Baggage?,
                     source: @autoclosure () -> String? = nil,
                     file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: .info, message(), metadata: metadata(), baggage: baggage, source: source(), file: file, function: function, line: line)
    }
    #endif

    /// Log a message passing with the ``Logger/Level/info`` log level.
    ///
    /// If `.info` is at least as severe as the `Logger`'s ``logLevel``, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message
    ///    - source: The source this log messages originates from. Defaults
    ///              to the module emitting the log message (on Swift 5.3 or
    ///              newer and the folder name containing the log emitting file on Swift 5.2 or
    ///              older).
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#fileID` (on Swift 5.3 or newer and `#file` on Swift 5.2 or older).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    #if compiler(>=5.3)
    @inlinable
    public func info(_ message: @autoclosure () -> Logger.Message,
                     metadata: @autoclosure () -> Logger.Metadata? = nil,
                     source: @autoclosure () -> String? = nil,
                     file: String = #fileID, function: String = #function, line: UInt = #line) {
        self.log(level: .info, message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
    }

    #else
    @inlinable
    public func info(_ message: @autoclosure () -> Logger.Message,
                     metadata: @autoclosure () -> Logger.Metadata? = nil,
                     source: @autoclosure () -> String? = nil,
                     file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: .info, message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
    }
    #endif

    /// Log a message passing with the ``Logger/Level/info`` log level.
    ///
    /// If `.info` is at least as severe as the `Logger`'s ``logLevel``, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message
    ///    - baggage: `Baggage` containing propagated runtime-generated metadata.
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#fileID` (on Swift 5.3 or newer and `#file` on Swift 5.2 or older).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    #if compiler(>=5.3)
    @inlinable
    public func info(_ message: @autoclosure () -> Logger.Message,
                     metadata: @autoclosure () -> Logger.Metadata? = nil,
                     baggage: Baggage?,
                     file: String = #fileID, function: String = #function, line: UInt = #line) {
        self.info(message(), metadata: metadata(), baggage: baggage, source: nil, file: file, function: function, line: line)
    }

    #else
    @inlinable
    public func info(_ message: @autoclosure () -> Logger.Message,
                     metadata: @autoclosure () -> Logger.Metadata? = nil,
                     baggage: Baggage?,
                     file: String = #file, function: String = #function, line: UInt = #line) {
        self.info(message(), metadata: metadata(), baggage: baggage, source: nil, file: file, function: function, line: line)
    }
    #endif

    /// Log a message passing with the ``Logger/Level/info`` log level.
    ///
    /// If `.info` is at least as severe as the `Logger`'s ``logLevel``, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#fileID` (on Swift 5.3 or newer and `#file` on Swift 5.2 or older).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    #if compiler(>=5.3)
    @inlinable
    public func info(_ message: @autoclosure () -> Logger.Message,
                     metadata: @autoclosure () -> Logger.Metadata? = nil,
                     file: String = #fileID, function: String = #function, line: UInt = #line) {
        self.info(message(), metadata: metadata(), source: nil, file: file, function: function, line: line)
    }

    #else
    @inlinable
    public func info(_ message: @autoclosure () -> Logger.Message,
                     metadata: @autoclosure () -> Logger.Metadata? = nil,
                     file: String = #file, function: String = #function, line: UInt = #line) {
        self.info(message(), metadata: metadata(), source: nil, file: file, function: function, line: line)
    }
    #endif

    /// Log a message passing with the ``Logger/Level/notice`` log level.
    ///
    /// If `.notice` is at least as severe as the `Logger`'s ``logLevel``, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message
    ///    - baggage: `Baggage` containing propagated runtime-generated metadata.
    ///    - source: The source this log messages originates from. Defaults
    ///              to the module emitting the log message (on Swift 5.3 or
    ///              newer and the folder name containing the log emitting file on Swift 5.2 or
    ///              older).
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#fileID` (on Swift 5.3 or newer and `#file` on Swift 5.2 or older).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    #if compiler(>=5.3)
    @inlinable
    public func notice(_ message: @autoclosure () -> Logger.Message,
                       metadata: @autoclosure () -> Logger.Metadata? = nil,
                       baggage: Baggage?,
                       source: @autoclosure () -> String? = nil,
                       file: String = #fileID, function: String = #function, line: UInt = #line) {
        self.log(level: .notice, message(), metadata: metadata(), baggage: baggage, source: source(), file: file, function: function, line: line)
    }

    #else
    @inlinable
    public func notice(_ message: @autoclosure () -> Logger.Message,
                       metadata: @autoclosure () -> Logger.Metadata? = nil,
                       baggage: Baggage?,
                       source: @autoclosure () -> String? = nil,
                       file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: .notice, message(), metadata: metadata(), baggage: baggage, source: source(), file: file, function: function, line: line)
    }
    #endif

    /// Log a message passing with the ``Logger/Level/notice`` log level.
    ///
    /// If `.notice` is at least as severe as the `Logger`'s ``logLevel``, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message
    ///    - source: The source this log messages originates from. Defaults
    ///              to the module emitting the log message (on Swift 5.3 or
    ///              newer and the folder name containing the log emitting file on Swift 5.2 or
    ///              older).
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#fileID` (on Swift 5.3 or newer and `#file` on Swift 5.2 or older).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    #if compiler(>=5.3)
    @inlinable
    public func notice(_ message: @autoclosure () -> Logger.Message,
                       metadata: @autoclosure () -> Logger.Metadata? = nil,
                       source: @autoclosure () -> String? = nil,
                       file: String = #fileID, function: String = #function, line: UInt = #line) {
        self.log(level: .notice, message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
    }

    #else
    @inlinable
    public func notice(_ message: @autoclosure () -> Logger.Message,
                       metadata: @autoclosure () -> Logger.Metadata? = nil,
                       source: @autoclosure () -> String? = nil,
                       file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: .notice, message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
    }
    #endif

    /// Log a message passing with the ``Logger/Level/notice`` log level.
    ///
    /// If `.notice` is at least as severe as the `Logger`'s ``logLevel``, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message
    ///    - baggage: `Baggage` containing propagated runtime-generated metadata.
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#fileID` (on Swift 5.3 or newer and `#file` on Swift 5.2 or older).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    #if compiler(>=5.3)
    @inlinable
    public func notice(_ message: @autoclosure () -> Logger.Message,
                       metadata: @autoclosure () -> Logger.Metadata? = nil,
                       baggage: Baggage?,
                       file: String = #fileID, function: String = #function, line: UInt = #line) {
        self.notice(message(), metadata: metadata(), baggage: baggage, source: nil, file: file, function: function, line: line)
    }

    #else
    @inlinable
    public func notice(_ message: @autoclosure () -> Logger.Message,
                       metadata: @autoclosure () -> Logger.Metadata? = nil,
                       baggage: Baggage?,
                       file: String = #file, function: String = #function, line: UInt = #line) {
        self.notice(message(), metadata: metadata(), baggage: baggage, source: nil, file: file, function: function, line: line)
    }
    #endif

    /// Log a message passing with the ``Logger/Level/notice`` log level.
    ///
    /// If `.notice` is at least as severe as the `Logger`'s ``logLevel``, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#fileID` (on Swift 5.3 or newer and `#file` on Swift 5.2 or older).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    #if compiler(>=5.3)
    @inlinable
    public func notice(_ message: @autoclosure () -> Logger.Message,
                       metadata: @autoclosure () -> Logger.Metadata? = nil,
                       file: String = #fileID, function: String = #function, line: UInt = #line) {
        self.notice(message(), metadata: metadata(), source: nil, file: file, function: function, line: line)
    }

    #else
    @inlinable
    public func notice(_ message: @autoclosure () -> Logger.Message,
                       metadata: @autoclosure () -> Logger.Metadata? = nil,
                       file: String = #file, function: String = #function, line: UInt = #line) {
        self.notice(message(), metadata: metadata(), source: nil, file: file, function: function, line: line)
    }
    #endif

    /// Log a message passing with the ``Logger/Level/warning`` log level.
    ///
    /// If `.warning` is at least as severe as the `Logger`'s ``logLevel``, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message
    ///    - baggage: `Baggage` containing propagated runtime-generated metadata.
    ///    - source: The source this log messages originates from. Defaults
    ///              to the module emitting the log message (on Swift 5.3 or
    ///              newer and the folder name containing the log emitting file on Swift 5.2 or
    ///              older).
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#fileID` (on Swift 5.3 or newer and `#file` on Swift 5.2 or older).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    #if compiler(>=5.3)
    @inlinable
    public func warning(_ message: @autoclosure () -> Logger.Message,
                        metadata: @autoclosure () -> Logger.Metadata? = nil,
                        baggage: Baggage?,
                        source: @autoclosure () -> String? = nil,
                        file: String = #fileID, function: String = #function, line: UInt = #line) {
        self.log(level: .warning, message(), metadata: metadata(), baggage: baggage, source: source(), file: file, function: function, line: line)
    }

    #else
    @inlinable
    public func warning(_ message: @autoclosure () -> Logger.Message,
                        metadata: @autoclosure () -> Logger.Metadata? = nil,
                        baggage: Baggage?,
                        source: @autoclosure () -> String? = nil,
                        file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: .warning, message(), metadata: metadata(), baggage: baggage, source: source(), file: file, function: function, line: line)
    }
    #endif

    /// Log a message passing with the ``Logger/Level/warning`` log level.
    ///
    /// If `.warning` is at least as severe as the `Logger`'s ``logLevel``, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message
    ///    - source: The source this log messages originates from. Defaults
    ///              to the module emitting the log message (on Swift 5.3 or
    ///              newer and the folder name containing the log emitting file on Swift 5.2 or
    ///              older).
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#fileID` (on Swift 5.3 or newer and `#file` on Swift 5.2 or older).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    #if compiler(>=5.3)
    @inlinable
    public func warning(_ message: @autoclosure () -> Logger.Message,
                        metadata: @autoclosure () -> Logger.Metadata? = nil,
                        source: @autoclosure () -> String? = nil,
                        file: String = #fileID, function: String = #function, line: UInt = #line) {
        self.log(level: .warning, message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
    }

    #else
    @inlinable
    public func warning(_ message: @autoclosure () -> Logger.Message,
                        metadata: @autoclosure () -> Logger.Metadata? = nil,
                        source: @autoclosure () -> String? = nil,
                        file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: .warning, message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
    }
    #endif

    /// Log a message passing with the ``Logger/Level/warning`` log level.
    ///
    /// If `.warning` is at least as severe as the `Logger`'s ``logLevel``, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message
    ///    - baggage: `Baggage` containing propagated runtime-generated metadata.
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#fileID` (on Swift 5.3 or newer and `#file` on Swift 5.2 or older).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    #if compiler(>=5.3)
    @inlinable
    public func warning(_ message: @autoclosure () -> Logger.Message,
                        metadata: @autoclosure () -> Logger.Metadata? = nil,
                        baggage: Baggage?,
                        file: String = #fileID, function: String = #function, line: UInt = #line) {
        self.warning(message(), metadata: metadata(), baggage: baggage, source: nil, file: file, function: function, line: line)
    }

    #else
    @inlinable
    public func warning(_ message: @autoclosure () -> Logger.Message,
                        metadata: @autoclosure () -> Logger.Metadata? = nil,
                        baggage: Baggage?,
                        file: String = #file, function: String = #function, line: UInt = #line) {
        self.warning(message(), metadata: metadata(), baggage: baggage, source: nil, file: file, function: function, line: line)
    }
    #endif

    /// Log a message passing with the ``Logger/Level/warning`` log level.
    ///
    /// If `.warning` is at least as severe as the `Logger`'s ``logLevel``, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#fileID` (on Swift 5.3 or newer and `#file` on Swift 5.2 or older).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    #if compiler(>=5.3)
    @inlinable
    public func warning(_ message: @autoclosure () -> Logger.Message,
                        metadata: @autoclosure () -> Logger.Metadata? = nil,
                        file: String = #fileID, function: String = #function, line: UInt = #line) {
        self.warning(message(), metadata: metadata(), source: nil, file: file, function: function, line: line)
    }

    #else
    @inlinable
    public func warning(_ message: @autoclosure () -> Logger.Message,
                        metadata: @autoclosure () -> Logger.Metadata? = nil,
                        file: String = #file, function: String = #function, line: UInt = #line) {
        self.warning(message(), metadata: metadata(), source: nil, file: file, function: function, line: line)
    }
    #endif

    /// Log a message passing with the ``Logger/Level/error`` log level.
    ///
    /// If `.error` is at least as severe as the `Logger`'s ``logLevel``, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message
    ///    - baggage: `Baggage` containing propagated runtime-generated metadata.
    ///    - source: The source this log messages originates from. Defaults
    ///              to the module emitting the log message (on Swift 5.3 or
    ///              newer and the folder name containing the log emitting file on Swift 5.2 or
    ///              older).
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#fileID` (on Swift 5.3 or newer and `#file` on Swift 5.2 or older).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    #if compiler(>=5.3)
    @inlinable
    public func error(_ message: @autoclosure () -> Logger.Message,
                      metadata: @autoclosure () -> Logger.Metadata? = nil,
                      baggage: Baggage?,
                      source: @autoclosure () -> String? = nil,
                      file: String = #fileID, function: String = #function, line: UInt = #line) {
        self.log(level: .error, message(), metadata: metadata(), baggage: baggage, source: source(), file: file, function: function, line: line)
    }

    #else
    @inlinable
    public func error(_ message: @autoclosure () -> Logger.Message,
                      metadata: @autoclosure () -> Logger.Metadata? = nil,
                      baggage: Baggage?,
                      source: @autoclosure () -> String? = nil,
                      file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: .error, message(), metadata: metadata(), baggage: baggage, source: source(), file: file, function: function, line: line)
    }
    #endif

    /// Log a message passing with the ``Logger/Level/error`` log level.
    ///
    /// If `.error` is at least as severe as the `Logger`'s ``logLevel``, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message
    ///    - source: The source this log messages originates from. Defaults
    ///              to the module emitting the log message (on Swift 5.3 or
    ///              newer and the folder name containing the log emitting file on Swift 5.2 or
    ///              older).
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#fileID` (on Swift 5.3 or newer and `#file` on Swift 5.2 or older).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    #if compiler(>=5.3)
    @inlinable
    public func error(_ message: @autoclosure () -> Logger.Message,
                      metadata: @autoclosure () -> Logger.Metadata? = nil,
                      source: @autoclosure () -> String? = nil,
                      file: String = #fileID, function: String = #function, line: UInt = #line) {
        self.log(level: .error, message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
    }

    #else
    @inlinable
    public func error(_ message: @autoclosure () -> Logger.Message,
                      metadata: @autoclosure () -> Logger.Metadata? = nil,
                      source: @autoclosure () -> String? = nil,
                      file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: .error, message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
    }
    #endif

    /// Log a message passing with the ``Logger/Level/error`` log level.
    ///
    /// If `.error` is at least as severe as the `Logger`'s ``logLevel``, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message
    ///    - baggage: `Baggage` containing propagated runtime-generated metadata.
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#fileID` (on Swift 5.3 or newer and `#file` on Swift 5.2 or older).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    #if compiler(>=5.3)
    @inlinable
    public func error(_ message: @autoclosure () -> Logger.Message,
                      metadata: @autoclosure () -> Logger.Metadata? = nil,
                      baggage: Baggage?,
                      file: String = #fileID, function: String = #function, line: UInt = #line) {
        self.error(message(), metadata: metadata(), baggage: baggage, source: nil, file: file, function: function, line: line)
    }

    #else
    @inlinable
    public func error(_ message: @autoclosure () -> Logger.Message,
                      metadata: @autoclosure () -> Logger.Metadata? = nil,
                      baggage: Baggage?,
                      file: String = #file, function: String = #function, line: UInt = #line) {
        self.error(message(), metadata: metadata(), baggage: baggage, source: nil, file: file, function: function, line: line)
    }
    #endif

    /// Log a message passing with the ``Logger/Level/error`` log level.
    ///
    /// If `.error` is at least as severe as the `Logger`'s ``logLevel``, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#fileID` (on Swift 5.3 or newer and `#file` on Swift 5.2 or older).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    #if compiler(>=5.3)
    @inlinable
    public func error(_ message: @autoclosure () -> Logger.Message,
                      metadata: @autoclosure () -> Logger.Metadata? = nil,
                      file: String = #fileID, function: String = #function, line: UInt = #line) {
        self.error(message(), metadata: metadata(), source: nil, file: file, function: function, line: line)
    }

    #else
    @inlinable
    public func error(_ message: @autoclosure () -> Logger.Message,
                      metadata: @autoclosure () -> Logger.Metadata? = nil,
                      file: String = #file, function: String = #function, line: UInt = #line) {
        self.error(message(), metadata: metadata(), source: nil, file: file, function: function, line: line)
    }
    #endif

    /// Log a message passing with the ``Logger/Level/critical`` log level.
    ///
    /// If `.critical` is at least as severe as the `Logger`'s ``logLevel``, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message
    ///    - baggage: `Baggage` containing propagated runtime-generated metadata.
    ///    - source: The source this log messages originates from. Defaults
    ///              to the module emitting the log message (on Swift 5.3 or
    ///              newer and the folder name containing the log emitting file on Swift 5.2 or
    ///              older).
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#fileID` (on Swift 5.3 or newer and `#file` on Swift 5.2 or older).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    #if compiler(>=5.3)
    @inlinable
    public func critical(_ message: @autoclosure () -> Logger.Message,
                         metadata: @autoclosure () -> Logger.Metadata? = nil,
                         baggage: Baggage?,
                         source: @autoclosure () -> String? = nil,
                         file: String = #fileID, function: String = #function, line: UInt = #line) {
        self.log(level: .critical, message(), metadata: metadata(), baggage: baggage, source: source(), file: file, function: function, line: line)
    }

    #else
    @inlinable
    public func critical(_ message: @autoclosure () -> Logger.Message,
                         metadata: @autoclosure () -> Logger.Metadata? = nil,
                         baggage: Baggage?,
                         source: @autoclosure () -> String? = nil,
                         file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: .critical, message(), metadata: metadata(), baggage: baggage, source: source(), file: file, function: function, line: line)
    }
    #endif

    /// Log a message passing with the ``Logger/Level/critical`` log level.
    ///
    /// If `.critical` is at least as severe as the `Logger`'s ``logLevel``, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message
    ///    - source: The source this log messages originates from. Defaults
    ///              to the module emitting the log message (on Swift 5.3 or
    ///              newer and the folder name containing the log emitting file on Swift 5.2 or
    ///              older).
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#fileID` (on Swift 5.3 or newer and `#file` on Swift 5.2 or older).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    #if compiler(>=5.3)
    @inlinable
    public func critical(_ message: @autoclosure () -> Logger.Message,
                         metadata: @autoclosure () -> Logger.Metadata? = nil,
                         source: @autoclosure () -> String? = nil,
                         file: String = #fileID, function: String = #function, line: UInt = #line) {
        self.log(level: .critical, message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
    }

    #else
    @inlinable
    public func critical(_ message: @autoclosure () -> Logger.Message,
                         metadata: @autoclosure () -> Logger.Metadata? = nil,
                         source: @autoclosure () -> String? = nil,
                         file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: .critical, message(), metadata: metadata(), source: source(), file: file, function: function, line: line)
    }
    #endif

    /// Log a message passing with the ``Logger/Level/critical`` log level.
    ///
    /// If `.critical` is at least as severe as the `Logger`'s ``logLevel``, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message
    ///    - baggage: `Baggage` containing propagated runtime-generated metadata.
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#fileID` (on Swift 5.3 or newer and `#file` on Swift 5.2 or older).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    #if compiler(>=5.3)
    @inlinable
    public func critical(_ message: @autoclosure () -> Logger.Message,
                         metadata: @autoclosure () -> Logger.Metadata? = nil,
                         baggage: Baggage?,
                         file: String = #fileID, function: String = #function, line: UInt = #line) {
        self.critical(message(), metadata: metadata(), baggage: baggage, source: nil, file: file, function: function, line: line)
    }

    #else
    @inlinable
    public func critical(_ message: @autoclosure () -> Logger.Message,
                         metadata: @autoclosure () -> Logger.Metadata? = nil,
                         baggage: Baggage?,
                         file: String = #file, function: String = #function, line: UInt = #line) {
        self.critical(message(), metadata: metadata(), baggage: baggage, source: nil, file: file, function: function, line: line)
    }
    #endif

    /// Log a message passing with the ``Logger/Level/critical`` log level.
    ///
    /// If `.critical` is at least as severe as the `Logger`'s ``logLevel``, it will be logged,
    /// otherwise nothing will happen.
    ///
    /// - parameters:
    ///    - message: The message to be logged. `message` can be used with any string interpolation literal.
    ///    - metadata: One-off metadata to attach to this log message
    ///    - file: The file this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#fileID` (on Swift 5.3 or newer and `#file` on Swift 5.2 or older).
    ///    - function: The function this log message originates from (there's usually no need to pass it explicitly as
    ///                it defaults to `#function`).
    ///    - line: The line this log message originates from (there's usually no need to pass it explicitly as it
    ///            defaults to `#line`).
    #if compiler(>=5.3)
    @inlinable
    public func critical(_ message: @autoclosure () -> Logger.Message,
                         metadata: @autoclosure () -> Logger.Metadata? = nil,
                         file: String = #fileID, function: String = #function, line: UInt = #line) {
        self.critical(message(), metadata: metadata(), source: nil, file: file, function: function, line: line)
    }

    #else
    @inlinable
    public func critical(_ message: @autoclosure () -> Logger.Message,
                         metadata: @autoclosure () -> Logger.Metadata? = nil,
                         file: String = #file, function: String = #function, line: UInt = #line) {
        self.critical(message(), metadata: metadata(), source: nil, file: file, function: function, line: line)
    }
    #endif
}

/// The `LoggingSystem` is a global facility where the default logging backend implementation (`LogHandler`) can be
/// configured. `LoggingSystem` is set up just once in a given program to set up the desired logging backend
/// implementation.
public enum LoggingSystem {
    private static let _factory = FactoryBox(StreamLogHandler.standardOutput)
    private static let _metadataProvider = MetadataProviderBox(nil)

    /// `bootstrap` is a one-time configuration function which globally selects the desired logging backend
    /// implementation. `bootstrap` can be called at maximum once in any given program, calling it more than once will
    /// lead to undefined behavior, most likely a crash.
    ///
    /// - parameters:
    ///     - metadataProvider: The `MetadataProvider` used to inject runtime-generated metadata, defaults to nil.
    ///     - factory: A closure that given a `Logger` identifier, produces an instance of the `LogHandler`.
    public static func bootstrap(metadataProvider: Logger.MetadataProvider? = nil,
                                 _ factory: @escaping (String) -> LogHandler) {
        self._metadataProvider.replaceMetadataProvider(metadataProvider, validate: true)
        self._factory.replaceFactory(factory, validate: true)
    }

    /// `bootstrap` is a one-time configuration function which globally selects the desired logging backend
    /// implementation. `bootstrap` can be called at maximum once in any given program, calling it more than once will
    /// lead to undefined behavior, most likely a crash.
    ///
    /// - parameters:
    ///     - factory: A closure that given a `Logger` identifier, produces an instance of the `LogHandler`.
    public static func bootstrap(_ factory: @escaping (String) -> LogHandler) {
        self.bootstrap(metadataProvider: nil, factory)
    }

    // for our testing we want to allow multiple bootstraping
    internal static func bootstrapInternal(metadataProvider: Logger.MetadataProvider? = nil,
                                           _ factory: @escaping (String) -> LogHandler) {
        self._metadataProvider.replaceMetadataProvider(metadataProvider, validate: false)
        self._factory.replaceFactory(factory, validate: false)
    }

    internal static func bootstrapInternal(_ factory: @escaping (String) -> LogHandler) {
        self.bootstrapInternal(metadataProvider: nil, factory)
    }

    fileprivate static var metadataProvider: Logger.MetadataProvider? {
        return self._metadataProvider.underlying
    }

    fileprivate static var factory: (String) -> LogHandler {
        return self._factory.underlying
    }

    private final class MetadataProviderBox {
        private let lock = ReadWriteLock()
        fileprivate var _underlying: Logger.MetadataProvider?
        private var initialized = false

        init(_ underlying: Logger.MetadataProvider?) {
            self._underlying = underlying
        }

        func replaceMetadataProvider(_ metadataProvider: Logger.MetadataProvider?, validate: Bool) {
            self.lock.withWriterLock {
                precondition(!validate || !self.initialized, "logging system can only be initialized once per process.")
                self._underlying = metadataProvider
                self.initialized = true
            }
        }

        var underlying: Logger.MetadataProvider? {
            return self.lock.withReaderLock {
                return self._underlying
            }
        }
    }

    private final class FactoryBox {
        private let lock = ReadWriteLock()
        fileprivate var _underlying: (String) -> LogHandler
        private var initialized = false

        init(_ underlying: @escaping (String) -> LogHandler) {
            self._underlying = underlying
        }

        func replaceFactory(_ factory: @escaping (String) -> LogHandler, validate: Bool) {
            self.lock.withWriterLock {
                precondition(!validate || !self.initialized, "logging system can only be initialized once per process.")
                self._underlying = factory
                self.initialized = true
            }
        }

        var underlying: (String) -> LogHandler {
            return self.lock.withReaderLock {
                return self._underlying
            }
        }
    }
}

extension Logger {
    /// `Metadata` is a typealias for `[String: Logger.MetadataValue]` the type of the metadata storage.
    public typealias Metadata = [String: MetadataValue]

    /// A logging metadata value. `Logger.MetadataValue` is string, array, and dictionary literal convertible.
    ///
    /// `MetadataValue` provides convenient conformances to `ExpressibleByStringInterpolation`,
    /// `ExpressibleByStringLiteral`, `ExpressibleByArrayLiteral`, and `ExpressibleByDictionaryLiteral` which means
    /// that when constructing `MetadataValue`s you should default to using Swift's usual literals.
    ///
    /// Examples:
    ///  - prefer `logger.info("user logged in", metadata: ["user-id": "\(user.id)"])` over
    ///    `..., metadata: ["user-id": .string(user.id.description)])`
    ///  - prefer `logger.info("user selected colors", metadata: ["colors": ["\(user.topColor)", "\(user.secondColor)"]])`
    ///    over `..., metadata: ["colors": .array([.string("\(user.topColor)"), .string("\(user.secondColor)")])`
    ///  - prefer `logger.info("nested info", metadata: ["nested": ["fave-numbers": ["\(1)", "\(2)", "\(3)"], "foo": "bar"]])`
    ///    over `..., metadata: ["nested": .dictionary(["fave-numbers": ...])])`
    public enum MetadataValue {
        /// A metadata value which is a `String`.
        ///
        /// Because `MetadataValue` implements `ExpressibleByStringInterpolation`, and `ExpressibleByStringLiteral`,
        /// you don't need to type `.string(someType.description)` you can use the string interpolation `"\(someType)"`.
        case string(String)

        /// A metadata value which is some `CustomStringConvertible`.
        #if compiler(>=5.7)
        case stringConvertible(CustomStringConvertible & Sendable)
        #else
        case stringConvertible(CustomStringConvertible)
        #endif
        /// A metadata value which is a dictionary from `String` to `Logger.MetadataValue`.
        ///
        /// Because `MetadataValue` implements `ExpressibleByDictionaryLiteral`, you don't need to type
        /// `.dictionary(["foo": .string("bar \(buz)")])`, you can just use the more natural `["foo": "bar \(buz)"]`.
        case dictionary(Metadata)

        /// A metadata value which is an array of `Logger.MetadataValue`s.
        ///
        /// Because `MetadataValue` implements `ExpressibleByArrayLiteral`, you don't need to type
        /// `.array([.string("foo"), .string("bar \(buz)")])`, you can just use the more natural `["foo", "bar \(buz)"]`.
        case array([Metadata.Value])
    }

    /// The log level.
    ///
    /// Log levels are ordered by their severity, with `.trace` being the least severe and
    /// `.critical` being the most severe.
    public enum Level: String, Codable, CaseIterable {
        /// Appropriate for messages that contain information normally of use only when
        /// tracing the execution of a program.
        case trace

        /// Appropriate for messages that contain information normally of use only when
        /// debugging a program.
        case debug

        /// Appropriate for informational messages.
        case info

        /// Appropriate for conditions that are not error conditions, but that may require
        /// special handling.
        case notice

        /// Appropriate for messages that are not error conditions, but more severe than
        /// `.notice`.
        case warning

        /// Appropriate for error conditions.
        case error

        /// Appropriate for critical error conditions that usually require immediate
        /// attention.
        ///
        /// When a `critical` message is logged, the logging backend (`LogHandler`) is free to perform
        /// more heavy-weight operations to capture system state (such as capturing stack traces) to facilitate
        /// debugging.
        case critical
    }

    /// Construct a `Logger` given a `label` identifying the creator of the `Logger`.
    ///
    /// The `label` should identify the creator of the `Logger`. This can be an application, a sub-system, or even
    /// a datatype.
    ///
    /// - parameters:
    ///     - label: An identifier for the creator of a `Logger`.
    public init(label: String) {
        self.init(label: label, LoggingSystem.factory(label), metadataProvider: LoggingSystem.metadataProvider)
    }

    /// Construct a `Logger` given a `label` identifying the creator of the `Logger` and a `MetadataProvider`.
    ///
    /// The `label` should identify the creator of the `Logger`. This can be an application, a sub-system, or even
    /// a datatype.
    ///
    /// - parameters:
    ///     - label: An identifier for the creator of a `Logger`.
    ///     - metadataProvider: The `MetadataProvider` used to inject runtime-generated metadata, defaults to nil.
    public init(label: String, metadataProvider: MetadataProvider) {
        self.init(label: label, LoggingSystem.factory(label), metadataProvider: metadataProvider)
    }

    /// Construct a `Logger` given a `label` identifying the creator of the `Logger` or a non-standard `LogHandler`.
    ///
    /// The `label` should identify the creator of the `Logger`. This can be an application, a sub-system, or even
    /// a datatype.
    ///
    /// This initializer provides an escape hatch in case the global default logging backend implementation (set up
    /// using `LoggingSystem.bootstrap` is not appropriate for this particular logger.
    ///
    /// - parameters:
    ///     - label: An identifier for the creator of a `Logger`.
    ///     - factory: A closure creating non-standard `LogHandler`s.
    public init(label: String,
                factory: (String) -> LogHandler) {
        self = Logger(label: label, factory(label), metadataProvider: LoggingSystem.metadataProvider)
    }

    /// Construct a `Logger` given a `label` identifying the creator of the `Logger` or a non-standard `LogHandler` and a `MetadataProvider`.
    ///
    /// The `label` should identify the creator of the `Logger`. This can be an application, a sub-system, or even
    /// a datatype.
    ///
    /// This initializer provides an escape hatch in case the global default logging backend implementation (set up
    /// using `LoggingSystem.bootstrap` is not appropriate for this particular logger.
    ///
    /// - parameters:
    ///     - label: An identifier for the creator of a `Logger`.
    ///     - factory: A closure creating non-standard `LogHandler`s.
    ///     - metadataProvider: The `MetadataProvider` used to inject runtime-generated metadata.
    public init(label: String,
                factory: (String) -> LogHandler,
                metadataProvider: MetadataProvider) {
        self = Logger(label: label, factory(label), metadataProvider: metadataProvider)
    }
}

extension Logger {
    /// A `MetadataProvider` is used to automatically inject runtime-generated metadata
    /// to all logs emitted by a logger.
    ///
    /// ### Example
    /// A metadata provider may be used to automatically inject metadata such as
    /// trace IDs:
    /// ```swift
    /// let metadataProvider = MetadataProvider { baggage in
    ///     guard let traceID = baggage?.traceID else { return nil }
    ///     return ["traceID": "\(traceID)"]
    /// }
    /// let logger = Logger(label: "example", metadataProvider: metadataProvider)
    /// var baggage = Baggage.topLevel
    /// baggage.traceID = 42
    /// Baggage.$current.withValue(baggage) {
    ///     logger.info("hello") // automatically includes ["traceID": "42"] metadata
    /// }
    /// ```
    #if swift(>=5.5) && canImport(_Concurrency)
    public struct MetadataProvider: Sendable {
        /// Extract `Metadata` from the given `Baggage`.
        public let metadata: @Sendable(_ baggage: Baggage?) -> Metadata?

        /// Create a new `MetadataProvider`.
        ///
        /// - Parameter metadata: A closure extracting metadata from a given `Baggage`.
        public init(metadata: @escaping @Sendable(Baggage?) -> Metadata?) {
            self.metadata = metadata
        }
    }

    #else
    public struct MetadataProvider {
        /// Extract `Metadata` from the given `Baggage`.
        public let metadata: (_ baggage: Baggage?) -> Metadata?

        /// Create a new `MetadataProvider`.
        ///
        /// - Parameter metadata: A closure extracting metadata from a given `Baggage`.
        public init(metadata: @escaping (Baggage?) -> Metadata?) {
            self.metadata = metadata
        }
    }
    #endif
}

extension Logger.MetadataProvider {
    /// A pseudo-`MetadataProvider` that can be used to merge metadata from multiple other `MetadataProvider`s.
    ///
    /// ### Merging conflicting keys
    ///
    /// `MetadataProvider`s are invoked left to right in the order specified in the `providers` argument.
    /// In case multiple providers try to add a value for the same key, the last provider "wins" and its value is being used.
    ///
    /// - Parameter providers: An array of `MetadataProvider`s to delegate to. The array must not be empty.
    /// - Returns: A pseudo-`MetadataProvider` merging metadata from the given `MetadataProvider`s.
    public static func multiplex(_ providers: [Logger.MetadataProvider]) -> Logger.MetadataProvider {
        assert(!providers.isEmpty, "providers MUST NOT be empty")
        return Logger.MetadataProvider { baggage in
            providers.reduce(into: nil) { metadata, provider in
                if let providedMetadata = provider.metadata(baggage) {
                    if metadata != nil {
                        metadata!.merge(providedMetadata, uniquingKeysWith: { _, rhs in rhs })
                    } else {
                        metadata = providedMetadata
                    }
                }
            }
        }
    }
}

extension Logger.Level {
    internal var naturalIntegralValue: Int {
        switch self {
        case .trace:
            return 0
        case .debug:
            return 1
        case .info:
            return 2
        case .notice:
            return 3
        case .warning:
            return 4
        case .error:
            return 5
        case .critical:
            return 6
        }
    }
}

extension Logger.Level: Comparable {
    public static func < (lhs: Logger.Level, rhs: Logger.Level) -> Bool {
        return lhs.naturalIntegralValue < rhs.naturalIntegralValue
    }
}

// Extension has to be done on explicit type rather than Logger.Metadata.Value as workaround for
// https://bugs.swift.org/browse/SR-9687
// Then we could write it as follows and it would work under Swift 5 and not only 4 as it does currently:
// extension Logger.Metadata.Value: Equatable {
extension Logger.MetadataValue: Equatable {
    public static func == (lhs: Logger.Metadata.Value, rhs: Logger.Metadata.Value) -> Bool {
        switch (lhs, rhs) {
        case (.string(let lhs), .string(let rhs)):
            return lhs == rhs
        case (.stringConvertible(let lhs), .stringConvertible(let rhs)):
            return lhs.description == rhs.description
        case (.array(let lhs), .array(let rhs)):
            return lhs == rhs
        case (.dictionary(let lhs), .dictionary(let rhs)):
            return lhs == rhs
        default:
            return false
        }
    }
}

extension Logger {
    /// `Logger.Message` represents a log message's text. It is usually created using string literals.
    ///
    /// Example creating a `Logger.Message`:
    ///
    ///     let world: String = "world"
    ///     let myLogMessage: Logger.Message = "Hello \(world)"
    ///
    /// Most commonly, `Logger.Message`s appear simply as the parameter to a logging method such as:
    ///
    ///     logger.info("Hello \(world)")
    ///
    public struct Message: ExpressibleByStringLiteral, Equatable, CustomStringConvertible, ExpressibleByStringInterpolation {
        public typealias StringLiteralType = String

        private var value: String

        public init(stringLiteral value: String) {
            self.value = value
        }

        public var description: String {
            return self.value
        }
    }
}

/// A pseudo-`LogHandler` that can be used to send messages to multiple other `LogHandler`s.
///
/// ### Effective Logger.Level
///
/// When first initialized the multiplex log handlers' log level is automatically set to the minimum of all the
/// passed in log handlers. This ensures that each of the handlers will be able to log at their appropriate level
/// any log events they might be interested in.
///
/// Example:
/// If log handler `A` is logging at `.debug` level, and log handler `B` is logging at `.info` level, the constructed
/// `MultiplexLogHandler([A, B])`'s effective log level will be set to `.debug`, meaning that debug messages will be
/// handled by this handler, while only logged by the underlying `A` log handler (since `B`'s log level is `.info`
/// and thus it would not actually log that log message).
///
/// If the log level is _set_ on a `Logger` backed by an `MultiplexLogHandler` the log level will apply to *all*
/// underlying log handlers, allowing a logger to still select at what level it wants to log regardless of if the underlying
/// handler is a multiplex or a normal one. If for some reason one might want to not allow changing a log level of a specific
/// handler passed into the multiplex log handler, this is possible by wrapping it in a handler which ignores any log level changes.
///
/// ### Effective Logger.Metadata
///
/// Since a `MultiplexLogHandler` is a combination of multiple log handlers, the handling of metadata can be non-obvious.
/// For example, the underlying log handlers may have metadata of their own set before they are used to initialize the multiplex log handler.
///
/// The multiplex log handler acts purely as proxy and does not make any changes to underlying handler metadata other than
/// proxying writes that users made on a `Logger` instance backed by this handler.
///
/// Setting metadata is always proxied through to _all_ underlying handlers, meaning that if a modification like
/// `logger[metadataKey: "x"] = "y"` is made, all underlying log handlers that this multiplex handler was initiated with
/// will observe this change.
///
/// Reading metadata from the multiplex log handler MAY need to pick one of conflicting values if the underlying log handlers
/// were already initiated with some metadata before passing them into the multiplex handler. The multiplex handler uses
/// the order in which the handlers were passed in during its initialization as a priority indicator - the first handler's
/// values are more important than the next handlers values, etc.
///
/// Example:
/// If the multiplex log handler was initiated with two handlers like this: `MultiplexLogHandler([handler1, handler2])`.
/// The handlers each have some already set metadata: `handler1` has metadata values for keys `one` and `all`, and `handler2`
/// has values for keys `two` and `all`.
///
/// A query through the multiplex log handler the key `one` naturally returns `handler1`'s value, and a query for `two`
/// naturally returns `handler2`'s value. Querying for the key `all` will return `handler1`'s value, as that handler was indicated
/// "more important" than the second handler. The same rule applies when querying for the `metadata` property of the
/// multiplex log handler - it constructs `Metadata` uniquing values.
public struct MultiplexLogHandler: LogHandler {
    private var handlers: [LogHandler]
    private var effectiveLogLevel: Logger.Level

    /// Create a `MultiplexLogHandler`.
    ///
    /// - parameters:
    ///    - handlers: An array of `LogHandler`s, each of which will receive the log messages sent to this `Logger`.
    ///                The array must not be empty.
    public init(_ handlers: [LogHandler]) {
        assert(!handlers.isEmpty, "MultiplexLogHandler.handlers MUST NOT be empty")
        self.handlers = handlers
        self.effectiveLogLevel = handlers.map { $0.logLevel }.min() ?? .trace
    }

    public var logLevel: Logger.Level {
        get {
            return self.effectiveLogLevel
        }
        set {
            self.mutatingForEachHandler { $0.logLevel = newValue }
            self.effectiveLogLevel = newValue
        }
    }

    public func log(level: Logger.Level,
                    message: Logger.Message,
                    metadata: Logger.Metadata?,
                    source: String,
                    file: String,
                    function: String,
                    line: UInt) {
        for handler in self.handlers where handler.logLevel <= level {
            handler.log(level: level, message: message, metadata: metadata, source: source, file: file, function: function, line: line)
        }
    }

    public var metadata: Logger.Metadata {
        get {
            var effectiveMetadata: Logger.Metadata = [:]
            // as a rough estimate we assume that the underlying handlers have a similar metadata count,
            // and we use the first one's current count to estimate how big of a dictionary we need to allocate:
            effectiveMetadata.reserveCapacity(self.handlers.first!.metadata.count) // !-safe, we always have at least one handler
            return self.handlers.reduce(into: effectiveMetadata) { effectiveMetadata, handler in
                effectiveMetadata.merge(handler.metadata, uniquingKeysWith: { l, _ in l })
            }
        }
        set {
            self.mutatingForEachHandler { $0.metadata = newValue }
        }
    }

    public subscript(metadataKey metadataKey: Logger.Metadata.Key) -> Logger.Metadata.Value? {
        get {
            for handler in self.handlers {
                if let value = handler[metadataKey: metadataKey] {
                    return value
                }
            }
            return nil
        }
        set {
            self.mutatingForEachHandler { $0[metadataKey: metadataKey] = newValue }
        }
    }

    private mutating func mutatingForEachHandler(_ mutator: (inout LogHandler) -> Void) {
        for index in self.handlers.indices {
            mutator(&self.handlers[index])
        }
    }
}

#if canImport(WASILibc) || os(Android)
internal typealias CFilePointer = OpaquePointer
#else
internal typealias CFilePointer = UnsafeMutablePointer<FILE>
#endif

/// A wrapper to facilitate `print`-ing to stderr and stdio that
/// ensures access to the underlying `FILE` is locked to prevent
/// cross-thread interleaving of output.
internal struct StdioOutputStream: TextOutputStream {
    internal let file: CFilePointer
    internal let flushMode: FlushMode

    internal func write(_ string: String) {
        self.contiguousUTF8(string).withContiguousStorageIfAvailable { utf8Bytes in
            #if os(Windows)
            _lock_file(self.file)
            #elseif canImport(WASILibc)
            // no file locking on WASI
            #else
            flockfile(self.file)
            #endif
            defer {
                #if os(Windows)
                _unlock_file(self.file)
                #elseif canImport(WASILibc)
                // no file locking on WASI
                #else
                funlockfile(self.file)
                #endif
            }
            _ = fwrite(utf8Bytes.baseAddress!, 1, utf8Bytes.count, self.file)
            if case .always = self.flushMode {
                self.flush()
            }
        }!
    }

    /// Flush the underlying stream.
    /// This has no effect when using the `.always` flush mode, which is the default
    internal func flush() {
        _ = fflush(self.file)
    }

    internal func contiguousUTF8(_ string: String) -> String.UTF8View {
        var contiguousString = string
        #if compiler(>=5.1)
        contiguousString.makeContiguousUTF8()
        #else
        contiguousString = string + ""
        #endif
        return contiguousString.utf8
    }

    internal static let stderr = StdioOutputStream(file: systemStderr, flushMode: .always)
    internal static let stdout = StdioOutputStream(file: systemStdout, flushMode: .always)

    /// Defines the flushing strategy for the underlying stream.
    internal enum FlushMode {
        case undefined
        case always
    }
}

// Prevent name clashes
#if os(macOS) || os(tvOS) || os(iOS) || os(watchOS)
let systemStderr = Darwin.stderr
let systemStdout = Darwin.stdout
#elseif os(Windows)
let systemStderr = CRT.stderr
let systemStdout = CRT.stdout
#elseif canImport(Glibc)
let systemStderr = Glibc.stderr!
let systemStdout = Glibc.stdout!
#elseif canImport(WASILibc)
let systemStderr = WASILibc.stderr!
let systemStdout = WASILibc.stdout!
#else
#error("Unsupported runtime")
#endif

/// `StreamLogHandler` is a simple implementation of `LogHandler` for directing
/// `Logger` output to either `stderr` or `stdout` via the factory methods.
public struct StreamLogHandler: LogHandler {
    #if compiler(>=5.6)
    internal typealias _SendableTextOutputStream = TextOutputStream & Sendable
    #else
    internal typealias _SendableTextOutputStream = TextOutputStream
    #endif

    /// Factory that makes a `StreamLogHandler` to directs its output to `stdout`
    public static func standardOutput(label: String) -> StreamLogHandler {
        return StreamLogHandler(label: label, stream: StdioOutputStream.stdout)
    }

    /// Factory that makes a `StreamLogHandler` to directs its output to `stderr`
    public static func standardError(label: String) -> StreamLogHandler {
        return StreamLogHandler(label: label, stream: StdioOutputStream.stderr)
    }

    private let stream: _SendableTextOutputStream
    private let label: String

    public var logLevel: Logger.Level = .info

    private var prettyMetadata: String?
    public var metadata = Logger.Metadata() {
        didSet {
            self.prettyMetadata = self.prettify(self.metadata)
        }
    }

    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            return self.metadata[metadataKey]
        }
        set {
            self.metadata[metadataKey] = newValue
        }
    }

    // internal for testing only
    internal init(label: String, stream: _SendableTextOutputStream) {
        self.label = label
        self.stream = stream
    }

    public func log(level: Logger.Level,
                    message: Logger.Message,
                    metadata: Logger.Metadata?,
                    source: String,
                    file: String,
                    function: String,
                    line: UInt) {
        let prettyMetadata = metadata?.isEmpty ?? true
            ? self.prettyMetadata
            : self.prettify(self.metadata.merging(metadata!, uniquingKeysWith: { _, new in new }))

        var stream = self.stream
        stream.write("\(self.timestamp()) \(level) \(self.label) :\(prettyMetadata.map { " \($0)" } ?? "") [\(source)] \(message)\n")
    }

    private func prettify(_ metadata: Logger.Metadata) -> String? {
        return !metadata.isEmpty
            ? metadata.lazy.sorted(by: { $0.key < $1.key }).map { "\($0)=\($1)" }.joined(separator: " ")
            : nil
    }

    private func timestamp() -> String {
        var buffer = [Int8](repeating: 0, count: 255)
        #if os(Windows)
        var timestamp: __time64_t = __time64_t()
        _ = _time64(&timestamp)

        var localTime: tm = tm()
        _ = _localtime64_s(&localTime, &timestamp)

        _ = strftime(&buffer, buffer.count, "%Y-%m-%dT%H:%M:%S%z", &localTime)
        #else
        var timestamp = time(nil)
        let localTime = localtime(&timestamp)
        strftime(&buffer, buffer.count, "%Y-%m-%dT%H:%M:%S%z", localTime)
        #endif
        return buffer.withUnsafeBufferPointer {
            $0.withMemoryRebound(to: CChar.self) {
                String(cString: $0.baseAddress!)
            }
        }
    }
}

/// No operation LogHandler, used when no logging is required
public struct SwiftLogNoOpLogHandler: LogHandler {
    public init() {}

    public init(_: String) {}

    @inlinable public func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, file: String, function: String, line: UInt) {}

    @inlinable public subscript(metadataKey _: String) -> Logger.Metadata.Value? {
        get {
            return nil
        }
        set {}
    }

    @inlinable public var metadata: Logger.Metadata {
        get {
            return [:]
        }
        set {}
    }

    @inlinable public var logLevel: Logger.Level {
        get {
            return .critical
        }
        set {}
    }
}

extension Logger {
    @inlinable
    internal static func currentModule(filePath: String = #file) -> String {
        let utf8All = filePath.utf8
        return filePath.utf8.lastIndex(of: UInt8(ascii: "/")).flatMap { lastSlash -> Substring? in
            utf8All[..<lastSlash].lastIndex(of: UInt8(ascii: "/")).map { secondLastSlash -> Substring in
                filePath[utf8All.index(after: secondLastSlash) ..< lastSlash]
            }
        }.map {
            String($0)
        } ?? "n/a"
    }

    #if compiler(>=5.3)
    @inlinable
    internal static func currentModule(fileID: String = #fileID) -> String {
        let utf8All = fileID.utf8
        if let slashIndex = utf8All.firstIndex(of: UInt8(ascii: "/")) {
            return String(fileID[..<slashIndex])
        } else {
            return "n/a"
        }
    }
    #endif
}

// Extension has to be done on explicit type rather than Logger.Metadata.Value as workaround for
// https://bugs.swift.org/browse/SR-9686
extension Logger.MetadataValue: ExpressibleByStringLiteral {
    public typealias StringLiteralType = String

    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

// Extension has to be done on explicit type rather than Logger.Metadata.Value as workaround for
// https://bugs.swift.org/browse/SR-9686
extension Logger.MetadataValue: CustomStringConvertible {
    public var description: String {
        switch self {
        case .dictionary(let dict):
            return dict.mapValues { $0.description }.description
        case .array(let list):
            return list.map { $0.description }.description
        case .string(let str):
            return str
        case .stringConvertible(let repr):
            return repr.description
        }
    }
}

// Extension has to be done on explicit type rather than Logger.Metadata.Value as workaround for
// https://bugs.swift.org/browse/SR-9687
extension Logger.MetadataValue: ExpressibleByStringInterpolation {}

// Extension has to be done on explicit type rather than Logger.Metadata.Value as workaround for
// https://bugs.swift.org/browse/SR-9686
extension Logger.MetadataValue: ExpressibleByDictionaryLiteral {
    public typealias Key = String
    public typealias Value = Logger.Metadata.Value

    public init(dictionaryLiteral elements: (String, Logger.Metadata.Value)...) {
        self = .dictionary(.init(uniqueKeysWithValues: elements))
    }
}

// Extension has to be done on explicit type rather than Logger.Metadata.Value as workaround for
// https://bugs.swift.org/browse/SR-9686
extension Logger.MetadataValue: ExpressibleByArrayLiteral {
    public typealias ArrayLiteralElement = Logger.Metadata.Value

    public init(arrayLiteral elements: Logger.Metadata.Value...) {
        self = .array(elements)
    }
}

// MARK: - Sendable support helpers

#if compiler(>=5.7.0)
extension Logger.MetadataValue: Sendable {} // on 5.7 `stringConvertible`'s value marked as Sendable; but if a value not conforming to Sendable is passed there, a warning is emitted. We are okay with warnings, but on 5.6 for the same situation an error is emitted (!)
#elseif compiler(>=5.6)
extension Logger.MetadataValue: @unchecked Sendable {} // sadly, On 5.6 a missing Sendable conformance causes an 'error' (specifically this is about `stringConvertible`'s value)
#endif

#if compiler(>=5.6)
extension Logger: Sendable {}
extension Logger.Level: Sendable {}
extension Logger.Message: Sendable {}
#endif
