import Foundation

@main
struct Passkey {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        guard let cmd = args.first else { usage(); exit(1) }

        do {
            switch cmd {
            case "store":
                guard args.count == 4 else { usage(); exit(1) }
                try KeychainHelper.store(password: args[3], service: args[1], account: args[2])
                print("stored.")
            case "fetch":
                guard args.count == 3 else { usage(); exit(1) }
                let pw = try KeychainHelper.fetch(
                    service: args[1],
                    account: args[2],
                    reason: "Unlock \(args[2]) @ \(args[1])"
                )
                print(pw)
            case "delete":
                guard args.count == 3 else { usage(); exit(1) }
                try KeychainHelper.delete(service: args[1], account: args[2])
                print("deleted.")
            default:
                usage(); exit(1)
            }
        } catch {
            fputs("error: \(error)\n", stderr)
            exit(1)
        }
    }

    private static func usage() {
        fputs(
            """
            usage:
              passkey store  <service> <account> <password>
              passkey fetch  <service> <account>
              passkey delete <service> <account>

            """,
            stderr
        )
    }
}
