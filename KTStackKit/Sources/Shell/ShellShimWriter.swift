import Foundation

struct ShellShimWriter {
    let paths: AppSupportPaths

    var helperPath: String { paths.shimBinDir.appendingPathComponent("ktstack-resolve").path }

    private let phpConfigIsolation = """
        __ktphp_dir="${target%/bin/*}"
        __ktphp_ver="${__ktphp_dir##*/}"
        __ktphp_root="${__ktphp_dir%/runtimes/php/*}"
        [ -d "$__ktphp_root/config/php/$__ktphp_ver" ] && export PHPRC="$__ktphp_root/config/php/$__ktphp_ver"
        [ -d "$__ktphp_dir/conf.d" ] && export PHP_INI_SCAN_DIR="$__ktphp_dir/conf.d"
        """

    func directBinaryShim(lang: String) -> String {
        let isolation = lang == "php" ? "\n" + phpConfigIsolation : ""
        return """
        #!/bin/sh
        export PATH=/usr/bin:/bin
        target="$("\(helperPath)" \(lang) "$PWD")" || { echo "ktstack: \(lang) is not installed — open KTStack to add a runtime" >&2; exit 127; }\(isolation)
        exec "$target" "$@"
        """
    }

    func pharShim(name: String, phar: String) -> String {
        """
        #!/bin/sh
        export PATH=/usr/bin:/bin
        phar="\(phar)"
        [ -f "$phar" ] || { echo "ktstack: \(name) is not provisioned — open KTStack to install it" >&2; exit 127; }
        target="$("\(helperPath)" php "$PWD")" || { echo "ktstack: php is not installed" >&2; exit 127; }
        \(phpConfigIsolation)
        exec "$target" "$phar" "$@"
        """
    }

    var shims: [String: String] {
        [
            "php": directBinaryShim(lang: "php"),
            "node": directBinaryShim(lang: "node"),
            "composer": pharShim(name: "composer", phar: paths.composerPhar.path),
            "wp": pharShim(name: "wp", phar: paths.wpCliPhar.path),
        ]
    }

    func writeShims() throws {
        let fm = FileManager.default
        for (name, body) in shims {
            let url = paths.shimBinDir.appendingPathComponent(name)
            try (body + "\n").data(using: .utf8)!.write(to: url, options: .atomic)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
    }
}
