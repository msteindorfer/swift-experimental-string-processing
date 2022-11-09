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
  enum CodingKeys: String, CodingKey {
    case instructions                 // ✅ `Codable`
    case staticElements               // ✅ `Codable`
    case staticSequences              // ✅ `Codable`
    case staticBitsets                // ✅ `Codable`
    // case staticConsumeFunctions    // ⚡️ code, not data
    // case staticTransformFunctions  // ⚡️ code, not data
    // case staticMatcherFunctions    // ⚡️ code, not data
    case registerInfo                 // ✅ `Codable`
    case enableTracing                // ✅ `Codable`
    case enableMetrics                // ✅ `Codable`
    case captureList                  // ✅ `Codable`
    case referencedCaptureOffsets     // ✅ `Codable`
    case initialOptions               // ✅ `Codable`
  }
}

extension MEProgram: Decodable {
  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    instructions = try values.decode(type(of: instructions), forKey: .instructions)
    staticElements = try values.decode(type(of: staticElements), forKey: .staticElements)
    staticSequences = try values.decode(type(of: staticSequences), forKey: .staticSequences)
    staticBitsets = try values.decode(type(of: staticBitsets), forKey: .staticBitsets)
    staticConsumeFunctions = [] // FIXME: how to deal functions?
    staticTransformFunctions = [] // FIXME: how to deal functions?
    staticMatcherFunctions = [] // FIXME: how to deal functions?
    registerInfo = try values.decode(type(of: registerInfo), forKey: .registerInfo)
    enableTracing = try values.decode(type(of: enableTracing), forKey: .enableTracing)
    enableMetrics = try values.decode(type(of: enableMetrics), forKey: .enableMetrics)
    captureList = try values.decode(type(of: captureList), forKey: .captureList)
    referencedCaptureOffsets = try values.decode(type(of: referencedCaptureOffsets), forKey: .referencedCaptureOffsets)
    initialOptions = try values.decode(type(of: initialOptions), forKey: .initialOptions)
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
