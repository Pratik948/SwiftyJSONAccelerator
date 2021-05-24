//
//  SwiftJSONModelFile.swift
//  SwiftyJSONAccelerator
//
//  Created by Karthikeya Udupa on 25/07/2019.
//  Copyright © 2019 Karthikeya Udupa. All rights reserved.
//

import Foundation
import SwiftyJSON

/// Provides support for SwiftyJSON library.
struct SwiftJSONModelFile: ModelFile {
    var fileName: String
    var type: ConstructType
    var component: ModelComponent
    var sourceJSON: JSON
    var configuration: ModelGenerationConfiguration?

    // MARK: - Initialisers.

    init() {
        fileName = ""
        type = ConstructType.structType
        component = ModelComponent()
        sourceJSON = JSON([])
    }

    mutating func setInfo(_ fileName: String, _ configuration: ModelGenerationConfiguration) {
        self.fileName = fileName
        type = configuration.constructType
        self.configuration = configuration
    }

    mutating func generateAndAddComponentsFor(_ property: PropertyComponent) {
        let isOptional = configuration!.variablesOptional
        let isArray = property.propertyType == .valueTypeArray || property.propertyType == .objectTypeArray
        let type = property.propertyType == .emptyArray ? "Any" : property.type

        switch property.propertyType {
        case .valueType, .valueTypeArray, .objectType, .objectTypeArray, .emptyArray:
            component.stringConstants.append(genStringConstant(property.constantName, property.key))
            component.declarations.append(genVariableDeclaration(property.name, type, isArray, isOptional))
            component.initialisers.append(genInitializer(property: property))
            component.initialiserFunctionComponent.append(genInitaliserFunctionAssignmentAndParams(property.name, type, isArray, isOptional))
        case .nullType:
            // Currently we do not deal with null values.
            break
        }
    }

    /// Format the incoming string is in the case format.
    ///
    /// - Parameters:
    ///   - constantName: Constant value to represent the variable.
    ///   - value: Value for the key that is used in the JSON.
    /// - Returns: Returns `case <constant> = "value"`.
    func genStringConstant(_ constantName: String, _ value: String) -> String {
        let component = constantName.components(separatedBy: ".")
        let caseName = component.last!
        return "case \(caseName)" + (caseName == value ? "" : " = \"\(value)\"")
    }

    /// Generate the variable declaration string
    ///
    /// - Parameters:
    ///   - name: variable name to be used
    ///   - type: variable type to use
    ///   - isArray: Is the value an object
    ///   - isOptional: Is optional variable kind
    /// - Returns: A string to use as the declration
    func genVariableDeclaration(_ name: String, _ type: String, _ isArray: Bool, _ isOptional: Bool) -> String {
        var internalType = type
        var isOptional = isOptional
        if isArray {
            internalType = "List<\(type)> = .init()"
            isOptional = false
        }
        switch type {
        case "Double", "Int":
            internalType = "RealmOptional<\(type)> = .init()"
            isOptional = false
        case "Bool":
            internalType = "Bool = false"
            isOptional = false
        default:
            break
        }
        return genPrimitiveVariableDeclaration(name, internalType, isOptional)
    }

    func genPrimitiveVariableDeclaration(_ name: String, _ type: String, _ isOptional: Bool) -> String {
        if configuration?.publicClassAndVariables ?? false {
            if isOptional {
                return "public dynamic var \(name): \(type)?"
            }
            return "public dynamic var \(name): \(type)"
        } else {
            if isOptional {
                return "dynamic var \(name): \(type)?"
            }
            return "dynamic var \(name): \(type)"
        }
    }

    /// Generate the variable declaration string
    ///
    /// - Parameters:
    ///   - name: variable name to be used
    ///   - type: variable type to use
    ///   - isArray: Is the value an object
    /// - Returns: A string to use as the declration
    func genInitaliserFunctionAssignmentAndParams(_ name: String, _ type: String, _ isArray: Bool, _ isOptional: Bool) -> InitialiserFunctionComponent {
        var result = InitialiserFunctionComponent(functionParameter: "", assignmentString: "")
        result.assignmentString = "self.\(name) = \(name)"

        var typeString = type
        if isArray {
            typeString = "[\(typeString)]"
        }
        if isOptional {
            typeString = "\(typeString)?"
        }
        result.functionParameter = "\(name): \(typeString)"
        return result
    }

    func genInitializer(property: PropertyComponent) -> String {
        let type = property.type
        let isArray = property.propertyType == .valueTypeArray || property.propertyType == .objectTypeArray
        let constantName = property.constantName
        let isOptional = configuration!.variablesOptional
        let name = property.name
        if isArray {
            let decodeMethod = isOptional ? "decodeIfPresent" : "decode"
            let component = constantName.components(separatedBy: ".")
            return "let \(name) = try container.\(decodeMethod)([\(type)].self, forKey: .\(component.last!)) ?? []\n        self.\(name).append(objectsIn: \(name))"
        }
        let decodeMethod: String
        var assigneeVariable = "\(name)"
        switch type {
        case "Bool":
            decodeMethod = "decodeToBoolIfPresent"
        case "Double":
            decodeMethod = "decodeToDoubleIfPresent"
            assigneeVariable += ".value"
        case "Int":
            decodeMethod = "decodeToIntIfPresent"
            assigneeVariable += ".value"
        case "String":
            decodeMethod = "decodeToStringIfPresent"
        default:
            let component = constantName.components(separatedBy: ".")
            decodeMethod = isOptional ? "decodeIfPresent" : "decode"
            return "\(assigneeVariable) = try container.\(decodeMethod)(\(type).self, forKey: .\(component.last!))"
        }
        let component = constantName.components(separatedBy: ".")
        return "\(assigneeVariable) = container.\(decodeMethod)(forKey: .\(component.last!))"
    }
}
