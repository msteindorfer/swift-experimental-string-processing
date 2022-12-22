//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

@_implementationOnly import _RegexParser

struct MEProgram {
  typealias Input = String

  typealias ConsumeFunction = (Input, Range<Input.Index>) -> Input.Index?
  typealias TransformFunction =
    (Input, Processor._StoredCapture) throws -> Any?
  typealias MatcherFunction =
    (Input, Input.Index, Range<Input.Index>) throws -> (Input.Index, Any)?

  var instructions: InstructionList<Instruction>

  var staticElements: [Input.Element]
  var staticSequences: [[Input.Element]]
  var staticBitsets: [DSLTree.CustomCharacterClass.AsciiBitset]
  var staticConsumeFunctions: [ConsumeFunction]
  var staticTransformFunctions: [TransformFunction]
  var staticMatcherFunctions: [MatcherFunction]

  var registerInfo: RegisterInfo

  var enableTracing: Bool
  var enableMetrics: Bool
  
  let captureList: CaptureList
  let referencedCaptureOffsets: [ReferenceID: Int]
  
  var initialOptions: MatchingOptions
}

extension MEProgram: CustomStringConvertible {
  var description: String {
    var result = """
    Elements: \(staticElements)

    """
    if !staticConsumeFunctions.isEmpty {
      result += "Consume functions: \(staticConsumeFunctions)"
    }

    // TODO: Extract into formatting code

    for idx in instructions.indices {
      let inst = instructions[idx]
      result += "[\(idx.rawValue)] \(inst)"
      if let ia = inst.instructionAddress {
        result += " // \(instructions[ia])"
      }
      result += "\n"
    }
    return result
  }
}

extension MEProgram: Encodable {
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    // TODO: prefer `instructions.rawValue` instead of phantom type wrapper
    try container.encode(instructions, forKey: .instructions)
    try container.encode(staticElements, forKey: .staticElements)
    try container.encode(staticSequences, forKey: .staticSequences)
    try container.encode(staticBitsets, forKey: .staticBitsets)
    try container.encode(registerInfo, forKey: .registerInfo)
    try container.encode(enableTracing, forKey: .enableTracing)
    try container.encode(enableMetrics, forKey: .enableMetrics)
    try container.encode(captureList, forKey: .captureList)
    try container.encode(referencedCaptureOffsets, forKey: .referencedCaptureOffsets)
    try container.encode(initialOptions, forKey: .initialOptions)

    if !staticConsumeFunctions.isEmpty {
      throw EncodingError.invalidValue(staticConsumeFunctions, EncodingError.Context(
        codingPath: [AdditionalInfoKeys.staticConsumeFunctions],
        debugDescription: "Consume functions cannot be encoded"))
    }

    if !staticTransformFunctions.isEmpty {
      throw EncodingError.invalidValue(staticTransformFunctions, EncodingError.Context(
        codingPath: [AdditionalInfoKeys.staticTransformFunctions],
        debugDescription: "Transform functions cannot be encoded"))
    }

    if !staticMatcherFunctions.isEmpty {
      throw EncodingError.invalidValue(staticMatcherFunctions, EncodingError.Context(
        codingPath: [AdditionalInfoKeys.staticMatcherFunctions],
        debugDescription: "Matcher functions cannot be encoded"))
    }
  }

  enum CodingKeys: String, CodingKey {
    case instructions                 // ✅ `Codable`
    case staticElements               // ✅ `Codable`
    case staticSequences              // ✅ `Codable`
    case staticBitsets                // ✅ `Codable`
    case registerInfo                 // ✅ `Codable`
    case enableTracing                // ✅ `Codable`
    case enableMetrics                // ✅ `Codable`
    case captureList                  // ✅ `Codable`
    case referencedCaptureOffsets     // ✅ `Codable`
    case initialOptions               // ✅ `Codable`
  }

  enum AdditionalInfoKeys: String, CodingKey {
    case staticConsumeFunctions       // ⚡️ code, not data
    case staticTransformFunctions     // ⚡️ code, not data
    case staticMatcherFunctions       // ⚡️ code, not data
  }
}

extension MEProgram: Decodable {
  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    // TODO: prefer `instructions.rawValue` instead of phantom type wrapper
    instructions = try values.decode(type(of: instructions), forKey: .instructions)
    staticElements = try values.decode(type(of: staticElements), forKey: .staticElements)
    staticSequences = try values.decode(type(of: staticSequences), forKey: .staticSequences)
    staticBitsets = try values.decode(type(of: staticBitsets), forKey: .staticBitsets)
    let __registerInfo = try values.decode(type(of: registerInfo), forKey: .registerInfo)
    registerInfo = __registerInfo
    enableTracing = try values.decode(type(of: enableTracing), forKey: .enableTracing)
    enableMetrics = try values.decode(type(of: enableMetrics), forKey: .enableMetrics)
    captureList = try values.decode(type(of: captureList), forKey: .captureList)
    referencedCaptureOffsets = try values.decode(type(of: referencedCaptureOffsets), forKey: .referencedCaptureOffsets)
    initialOptions = try values.decode(type(of: initialOptions), forKey: .initialOptions)

    // FIXME: how to inject functions after deserialization?

    // Emit placeholders throwing fatal error
    staticConsumeFunctions = (0 ..< __registerInfo.consumeFunctions).map { _ in
      { _, _ in fatalError("Consume function not initialized") }
    }

    // Emit placeholders throwing fatal error
    staticTransformFunctions = (0 ..< __registerInfo.transformFunctions).map { _ in
      { _, _ in fatalError("Transform function not initialized") }
    }

    // Emit placeholders throwing fatal error
    staticMatcherFunctions = (0 ..< __registerInfo.matcherFunctions).map { _ in
      { _, _, _ in fatalError("Matcher function not initialized") }
    }
  }
}

// TODO: move somewhere else; used for `staticElements` and `staticSequences`
extension Character: Codable {
  public init(from decoder: Decoder) throws {
    let values = try decoder.singleValueContainer()
    let string = try values.decode(String.self)

    guard let character = string.first, string.count == 1 else {
      throw DecodingError.dataCorruptedError(in: values, debugDescription: "Decoder expected a single character but found a string: \"\(string)\"")
    }

    self = character
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(String(self))
  }
}
