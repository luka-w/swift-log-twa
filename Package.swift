// swift-tools-version:5.0
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

import PackageDescription

let package = Package(
    name: "swift-log",
    platforms: [
       .macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v5)
    ],
    products: [
        .library(name: "Logging", targets: ["Logging"]),
    ],
    targets: [
        .target(
            name: "Logging",
            dependencies: []
        ),
        .testTarget(
            name: "LoggingTests",
            dependencies: ["Logging"]
        ),
    ]
)
