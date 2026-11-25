#!/usr/bin/env swift
import Foundation

let supportedLocales = ["en", "zh-Hans", "zh-Hant", "ja", "vi", "ko"]
let root = URL(
    fileURLWithPath: CommandLine.arguments.count > 1
        ? CommandLine.arguments[1]
        : FileManager.default.currentDirectoryPath,
    isDirectory: true
)
let localizationDirectory = root.appendingPathComponent("Resources/Localization", isDirectory: true)
let infoPlistURL = root.appendingPathComponent("Resources/Info.plist", isDirectory: false)

var failures: [String] = []
var checkedValues = 0

func report(_ message: String) {
    failures.append(message)
}

func isBlank(_ value: String) -> Bool {
    value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

func placeholders(in value: String) -> [String]? {
    let characters = Array(value)
    var result: [String] = []
    var index = 0

    while index < characters.count {
        guard characters[index] == "%" else {
            index += 1
            continue
        }

        index += 1
        guard index < characters.count else { return nil }
        if characters[index] == "%" {
            index += 1
            continue
        }

        var token = "%"
        var digits = ""
        while index < characters.count, characters[index].isNumber {
            digits.append(characters[index])
            index += 1
        }
        if !digits.isEmpty {
            guard index < characters.count, characters[index] == "$" else { return nil }
            token += "\(digits)$"
            index += 1
        }

        guard index < characters.count else { return nil }
        switch characters[index] {
        case "@":
            token += "@"
            index += 1
        case "d":
            token += "d"
            index += 1
        case "s":
            token += "s"
            index += 1
        case "l":
            token += "l"
            index += 1
            if index < characters.count, characters[index] == "l" {
                token += "l"
                index += 1
            }
            guard index < characters.count, characters[index] == "d" else { return nil }
            token += "d"
            index += 1
        default:
            return nil
        }
        result.append(token)
    }
    return result
}

func checkState(_ unit: [String: Any], context: String) {
    guard let state = unit["state"] as? String, !state.isEmpty else {
        report("\(context): missing localization state")
        return
    }
    if state == "new" {
        report("\(context): string is still in the 'new' state")
    }
}

func stringUnitValue(_ unit: [String: Any], context: String) -> String? {
    guard let value = unit["value"] as? String else {
        report("\(context): missing value")
        return nil
    }
    guard !isBlank(value) else {
        report("\(context): empty value")
        return nil
    }
    checkState(unit, context: context)
    return value
}

func validateCatalog(named name: String) -> [String: Any]? {
    let url = localizationDirectory.appendingPathComponent(name, isDirectory: false)
    guard FileManager.default.fileExists(atPath: url.path) else {
        report("\(name): missing catalog at \(url.path)")
        return nil
    }

    let data: Data
    do {
        data = try Data(contentsOf: url)
    } catch {
        report("\(name): cannot read catalog: \(error.localizedDescription)")
        return nil
    }

    let object: Any
    do {
        object = try JSONSerialization.jsonObject(with: data)
    } catch {
        report("\(name): invalid JSON: \(error.localizedDescription)")
        return nil
    }

    guard let catalog = object as? [String: Any] else {
        report("\(name): catalog root is not an object")
        return nil
    }
    guard let sourceLanguage = catalog["sourceLanguage"] as? String else {
        report("\(name): missing sourceLanguage")
        return nil
    }
    guard sourceLanguage == "en" else {
        report("\(name): sourceLanguage must be 'en', found '\(sourceLanguage)'")
        return nil
    }
    guard let strings = catalog["strings"] as? [String: Any], !strings.isEmpty else {
        report("\(name): missing or empty strings table")
        return nil
    }
    return strings
}

func validateCatalogValues(named name: String, strings: [String: Any]) {
    for key in strings.keys.sorted() {
        guard let entry = strings[key] as? [String: Any] else {
            report("\(name): \(key): entry is not an object")
            continue
        }
        guard let localizations = entry["localizations"] as? [String: Any] else {
            report("\(name): \(key): missing localizations")
            continue
        }

        var referencePlaceholders: [String]?
        var referenceLocaleValueFound = false

        for locale in supportedLocales {
            let context = "\(name): \(key) [\(locale)]"
            guard let localizedEntry = localizations[locale] as? [String: Any] else {
                report("\(context): missing localization")
                continue
            }

            let hasUnit = localizedEntry["stringUnit"] != nil
            let hasVariations = localizedEntry["variations"] != nil
            guard hasUnit != hasVariations else {
                report("\(context): must contain exactly one of stringUnit or variations")
                continue
            }

            var values: [(path: String, value: String)] = []

            if let unit = localizedEntry["stringUnit"] as? [String: Any] {
                if let value = stringUnitValue(unit, context: context) {
                    values.append(("", value))
                }
            } else if let variations = localizedEntry["variations"] as? [String: Any] {
                if locale != "en" {
                    report("\(context): plural variations are only allowed for the English source")
                }
                guard variations.keys.sorted() == ["plural"] else {
                    report("\(context): only plural variations are supported")
                    continue
                }
                guard let plural = variations["plural"] as? [String: Any], !plural.isEmpty else {
                    report("\(context): empty plural variations")
                    continue
                }
                if locale == "en" {
                    let categories = Set(plural.keys)
                    if categories != Set(["one", "other"]) {
                        report("\(context): English plural variations must contain exactly 'one' and 'other'")
                    }
                }
                for category in plural.keys.sorted() {
                    guard let categoryEntry = plural[category] as? [String: Any],
                          let unit = categoryEntry["stringUnit"] as? [String: Any] else {
                        report("\(context): plural variation '\(category)' is missing stringUnit")
                        continue
                    }
                    if let value = stringUnitValue(unit, context: "\(context): plural.\(category)") {
                        values.append(("plural.\(category)", value))
                    }
                }
            } else {
                report("\(context): missing stringUnit or plural variations")
                continue
            }

            guard !values.isEmpty else { continue }

            for (path, value) in values {
                checkedValues += 1
                guard let found = placeholders(in: value) else {
                    report("\(context)\(path.isEmpty ? "" : " \(path)"): unsupported or malformed format placeholder")
                    continue
                }
                if locale == "en" {
                    if let referencePlaceholders {
                        if found.sorted() != referencePlaceholders.sorted() {
                            report("\(context): English source values disagree on format placeholders")
                        }
                    } else {
                        referencePlaceholders = found
                        referenceLocaleValueFound = true
                    }
                } else if let referencePlaceholders {
                    if found.sorted() != referencePlaceholders.sorted() {
                        report(
                            "\(context)\(path.isEmpty ? "" : " \(path)"): format placeholders "
                                + "\(found) do not match English \(referencePlaceholders)"
                        )
                    }
                }
            }
        }

        if !referenceLocaleValueFound {
            report("\(name): \(key): English source value is missing")
        }
    }
}

func validateInfoPlist() {
    guard FileManager.default.fileExists(atPath: infoPlistURL.path) else {
        report("Resources/Info.plist: missing")
        return
    }
    do {
        let data = try Data(contentsOf: infoPlistURL)
        let object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let plist = object as? [String: Any] else {
            report("Resources/Info.plist: root is not a dictionary")
            return
        }
        if let developmentRegion = plist["CFBundleDevelopmentRegion"] as? String {
            if developmentRegion != "en" {
                report("Resources/Info.plist: CFBundleDevelopmentRegion must be 'en'")
            }
        } else {
            report("Resources/Info.plist: missing CFBundleDevelopmentRegion")
        }
        guard let localizations = plist["CFBundleLocalizations"] as? [String] else {
            report("Resources/Info.plist: missing CFBundleLocalizations")
            return
        }
        if Set(localizations) != Set(supportedLocales) {
            report(
                "Resources/Info.plist: CFBundleLocalizations \(localizations.sorted()) "
                    + "do not match supported locales \(supportedLocales)"
            )
        }
    } catch {
        report("Resources/Info.plist: cannot read plist: \(error.localizedDescription)")
    }
}

if let strings = validateCatalog(named: "Localizable.xcstrings") {
    validateCatalogValues(named: "Localizable.xcstrings", strings: strings)
}
if let strings = validateCatalog(named: "InfoPlist.xcstrings") {
    if !strings.keys.contains("NSHumanReadableCopyright") {
        report("InfoPlist.xcstrings: missing NSHumanReadableCopyright")
    }
    validateCatalogValues(named: "InfoPlist.xcstrings", strings: strings)
}
validateInfoPlist()

if failures.isEmpty {
    print("Localization catalogs are complete (\(checkedValues) localized values, \(supportedLocales.count) locales).")
} else {
    for failure in failures {
        FileHandle.standardError.write(Data("error: \(failure)\n".utf8))
    }
    FileHandle.standardError.write(
        Data("error: \(failures.count) localization validation failure(s)\n".utf8)
    )
    exit(1)
}
