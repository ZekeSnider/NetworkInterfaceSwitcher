import Foundation
public final class CommandLineTool {
    private let arguments: [String]

    public init(arguments: [String] = CommandLine.arguments) { 
        self.arguments = arguments
    }

    public func run() throws {
        guard arguments.count == 2 else {
            print("Error: incorrect number of parameters specified")
            return
        }

        let search = arguments[1]

        let networkList = shell(launchPath: "/usr/sbin/networksetup", arguments: ["listnetworkserviceorder"])

        var interfaceArray = [String]()

        networkList.enumerateLines { (line, stop) -> () in
            let regexmatch = self.matches(for: "^\\(([1-9][0-9]*)\\).*", in: line)
            if (regexmatch.count == 1) {
                interfaceArray.append(self.trimString(of: line))
            }
        }

        guard let i = interfaceArray.index(of: search) else {
            print("Error: The specified network interface was not found in the interface list.")
            return
        }

        interfaceArray.remove(at: i)
        interfaceArray.insert(search, at: 0)
        interfaceArray.insert("ordernetworkservices", at: 0)

        let _ = shell(launchPath: "/usr/sbin/networksetup", arguments: interfaceArray)
        print("Succesfully updated the network interface priority.")
    }

    private func shell(launchPath: String, arguments: [String]) -> String
    {
        let task = Process()
        task.launchPath = launchPath
        task.arguments = arguments

        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output: String = String(data: data, encoding: String.Encoding.utf8)!

        return output
    }

    private func matches(for regex: String, in text: String) -> [String] {
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let results = regex.matches(in: text,
                                        range: NSRange(text.startIndex..., in: text))
            return results.map {
                String(text[Range($0.range, in: text)!])
            }
        } catch let error {
            print("invalid regex: \(error.localizedDescription)")
            return []
        }
    }

    private func trimString(of input: String) -> String {
        let splitString = input.components(separatedBy: ") ")
        if splitString.count == 2 {
            return splitString[1]
        }
        else {
            return input
        }
    }
}