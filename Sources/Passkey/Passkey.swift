import Foundation

@main
struct Passkey {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())

        do {
            let (keychainPath, cmdArgs) = extractKeychainOption(from: args)
            guard let cmd = cmdArgs.first else { usage(); exit(1) }
            let keychain = try keychainPath.map(openKeychain)

            switch cmd {
            case "store":
                guard cmdArgs.count == 4 else { usage(); exit(1) }
                try KeychainHelper.store(
                    password: cmdArgs[3],
                    service: cmdArgs[1],
                    account: cmdArgs[2],
                    keychain: keychain
                )
                print("stored.")
            case "fetch":
                guard cmdArgs.count == 3 else { usage(); exit(1) }
                let pw = try KeychainHelper.fetch(
                    service: cmdArgs[1],
                    account: cmdArgs[2],
                    reason: "Unlock \(cmdArgs[2]) @ \(cmdArgs[1])",
                    keychain: keychain
                )
                print(pw)
            case "delete":
                guard cmdArgs.count == 3 else { usage(); exit(1) }
                try KeychainHelper.delete(
                    service: cmdArgs[1],
                    account: cmdArgs[2],
                    keychain: keychain
                )
                print("deleted.")
            default:
                usage(); exit(1)
            }
        } catch {
            fputs("error: \(error)\n", stderr)
            exit(1)
        }
    }

    private static func extractKeychainOption(from args: [String]) -> (String?, [String]) {
        guard let idx = args.firstIndex(of: "--keychain"), idx + 1 < args.count else {
            return (nil, args)
        }
        var filtered = args
        let path = filtered.remove(at: idx + 1)
        filtered.remove(at: idx)
        return (path, filtered)
    }

    // SecKeychainOpen is deprecated but remains the only API for opening a keychain by file path.
    // The modern Data Protection Keychain APIs don't support arbitrary keychain files.
    @available(macOS, deprecated: 10.10)
    private static func openKeychain(_ path: String) throws -> SecKeychain {
        var keychain: SecKeychain?
        let status = SecKeychainOpen(path, &keychain)
        guard status == errSecSuccess, let kc = keychain else {
            throw KeychainError.osStatus(status)
        }
        return kc
    }

    private static func usage() {
        fputs(
            """
            usage:
              passkey [--keychain <path>] store  <service> <account> <password>
              passkey [--keychain <path>] fetch  <service> <account>
              passkey [--keychain <path>] delete <service> <account>

            """,
            stderr
        )
    }
}
