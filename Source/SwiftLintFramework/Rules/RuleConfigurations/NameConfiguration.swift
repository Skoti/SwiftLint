import Foundation

public struct NameConfiguration: RuleConfiguration, Equatable {
    public var consoleDescription: String {
        return "(min_length) \(minLength.shortConsoleDescription), " +
            "(max_length) \(maxLength.shortConsoleDescription), " +
            "excluded: \(excluded.sorted()), " +
            "allowed_symbols: \(allowedSymbolsSet.sorted()), " +
            "validates_start_with_lowercase: \(validatesStartWithLowercase)"
    }

    var minLength: SeverityLevelsConfiguration
    var maxLength: SeverityLevelsConfiguration
    var excluded: Set<String>
    private var allowedSymbolsSet: Set<String>
    private var allowedSymbolsSetForConstants: Set<String>?
    var validatesStartWithLowercase: Bool

    var minLengthThreshold: Int {
        return max(minLength.warning, minLength.error ?? minLength.warning)
    }

    var maxLengthThreshold: Int {
        return min(maxLength.warning, maxLength.error ?? maxLength.warning)
    }

    var allowedSymbols: CharacterSet {
        return CharacterSet(safeCharactersIn: allowedSymbolsSet.joined())
    }

    var allowedSymbolsForConstants: CharacterSet? {
        guard let allowedSymbolsSetForConstants = allowedSymbolsSetForConstants else {
            return nil
        }
        return CharacterSet(safeCharactersIn: allowedSymbolsSetForConstants.joined())
    }

    public init(minLengthWarning: Int,
                minLengthError: Int,
                maxLengthWarning: Int,
                maxLengthError: Int,
                excluded: [String] = [],
                allowedSymbols: [String] = [],
                allowedSymbolsForConstants: [String]? = nil,
                validatesStartWithLowercase: Bool = true) {
        minLength = SeverityLevelsConfiguration(warning: minLengthWarning, error: minLengthError)
        maxLength = SeverityLevelsConfiguration(warning: maxLengthWarning, error: maxLengthError)
        self.excluded = Set(excluded)
        self.allowedSymbolsSet = Set(allowedSymbols)
        if let allowedSymbolsForConstants = allowedSymbolsForConstants {
            self.allowedSymbolsSetForConstants = Set(allowedSymbolsForConstants)
        }
        self.validatesStartWithLowercase = validatesStartWithLowercase
    }

    public mutating func apply(configuration: Any) throws {
        guard let configurationDict = configuration as? [String: Any] else {
            throw ConfigurationError.unknownConfiguration
        }

        if let minLengthConfiguration = configurationDict["min_length"] {
            try minLength.apply(configuration: minLengthConfiguration)
        }
        if let maxLengthConfiguration = configurationDict["max_length"] {
            try maxLength.apply(configuration: maxLengthConfiguration)
        }
        if let excluded = [String].array(of: configurationDict["excluded"]) {
            self.excluded = Set(excluded)
        }
        if let allowedSymbols = [String].array(of: configurationDict["allowed_symbols"]) {
            self.allowedSymbolsSet = Set(allowedSymbols)
        }
        if let allowedSymbolsForConstants = [String].array(of: configurationDict["allowed_symbols_for_constants"]) {
            self.allowedSymbolsSetForConstants = Set(allowedSymbolsForConstants)
        }

        if let validatesStartWithLowercase = configurationDict["validates_start_with_lowercase"] as? Bool {
            self.validatesStartWithLowercase = validatesStartWithLowercase
        } else if let validatesStartWithLowercase = configurationDict["validates_start_lowercase"] as? Bool {
            self.validatesStartWithLowercase = validatesStartWithLowercase
            queuedPrintError("\"validates_start_lowercase\" configuration was renamed to " +
                "\"validates_start_with_lowercase\" and will be removed in a future release.")
        }
    }

    public static func == (lhs: NameConfiguration, rhs: NameConfiguration) -> Bool {
        var result = lhs.minLength == rhs.minLength &&
            lhs.maxLength == rhs.maxLength &&
            zip(lhs.excluded, rhs.excluded).reduce(true) { $0 && ($1.0 == $1.1) } &&
            zip(lhs.allowedSymbolsSet, rhs.allowedSymbolsSet).reduce(true) { $0 && ($1.0 == $1.1) }

        if result {
            switch (lhs.allowedSymbolsSetForConstants, rhs.allowedSymbolsSetForConstants) {
            case (.none, .some), (.some, .none):
                result = false
            case let (.some(lhsConstantAllowedSymbols), .some(rhsConstantAllowedSymbols)):
                result = zip(lhsConstantAllowedSymbols, rhsConstantAllowedSymbols).reduce(true) { $0 && ($1.0 == $1.1) }
            default: break
            }
        }
        return result && lhs.validatesStartWithLowercase == rhs.validatesStartWithLowercase
    }
}

// MARK: - ConfigurationProviderRule extensions

public extension ConfigurationProviderRule where ConfigurationType == NameConfiguration {
    func severity(forLength length: Int) -> ViolationSeverity? {
        if let minError = configuration.minLength.error, length < minError {
            return .error
        } else if let maxError = configuration.maxLength.error, length > maxError {
            return .error
        } else if length < configuration.minLength.warning ||
                  length > configuration.maxLength.warning {
            return .warning
        }
        return nil
    }
}
