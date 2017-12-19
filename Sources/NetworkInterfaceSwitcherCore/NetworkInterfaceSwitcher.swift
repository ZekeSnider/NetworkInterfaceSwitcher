import Foundation
public final class CommandLineTool {
    private let arguments: [String]
    private var lookups: [String: String]
    static let networksetup:String = "/usr/sbin/networksetup" 

    public init(arguments: [String] = CommandLine.arguments) { 
        self.arguments = arguments
        self.lookups = [String: String]()
    }

    private enum commandType {
        case switchInterface
        case toggleInterface
    }

    public func run() throws {
        print(arguments)
        var parseLocation = 1
        var execCommandtype: commandType?
        var commandParameter: String?

        while parseLocation < arguments.count {
            switch arguments[parseLocation] {
                case "-s":
                    execCommandtype = .switchInterface
                    parseLocation += 1
                    if (parseLocation < arguments.count) {
                        commandParameter = arguments[parseLocation]
                        parseLocation += 1
                    }
                case "-t":
                    execCommandtype = .toggleInterface
                    parseLocation += 1
                    if (parseLocation < arguments.count) {
                        commandParameter = arguments[parseLocation]
                        parseLocation += 1
                    }
                case "-l":
                    parseLocation += 1
                    if (parseLocation < arguments.count) {
                        extractLoopkup(fromFile: arguments[parseLocation])
                        parseLocation += 1
                    }
                default:
                    print("unknown parameter provided " + arguments[parseLocation])
                    parseLocation += 1
            }
        }

        guard execCommandtype != nil else {
            print("No command provided.")
            return
        }
        guard commandParameter != nil else {
            print("no parameter provided")
            return
        }

        switch execCommandtype! {
            case .switchInterface:
                Switch(ToInterface: commandParameter!)
            case .toggleInterface:
                Toggle(FromFile: commandParameter!)
        }
    }

    public func Switch(ToInterface interface: String) {
        //Execute shell command to get list of network service order
        let networkList = shell(launchPath: CommandLineTool.networksetup, arguments: ["listnetworkserviceorder"])

        switchInterface(fromList: networkList, to: translateLookup(fromInterface: interface))
    }

    private func translateLookup(fromInterface interface: String) -> String {
        if (lookups[interface] != nil) {
            return lookups[interface]!
        }
        else {
            return interface
        }
    }

    public func Toggle(FromFile file: String) {
        let pwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let fileDir = pwd.appendingPathComponent(file)
        do {
            let toggleArray = try String(contentsOf: fileDir, encoding: .utf8).components(separatedBy: .newlines)

            //Execute shell command to get list of network service order
            let networkList = shell(launchPath: CommandLineTool.networksetup, arguments: ["listnetworkserviceorder"])
            let interfaceArray = extractIntefaceArray(from: networkList)

            switchInterface(fromList: networkList, to: determineToggle(interfaces: interfaceArray, toggles: toggleArray)!)
        }
        catch {
            print("Could not open toggle file " + file + ".")
        }
    }

    private func extractLoopkup(fromFile fileName:String) {
        let pwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let fileDir = pwd.appendingPathComponent(fileName)
        do {
            let lookupArray = try String(contentsOf: fileDir, encoding: .utf8).components(separatedBy: .newlines)
            for lookup in lookupArray {
                let components = lookup.components(separatedBy: ":")
                if components.count == 2 {
                    self.lookups[components[0]] = components[1]
                }
            }
        }
        catch {
            print("Could not open lookup file " + fileName + ". Ignoring lookup.")
            lookups = [:]
        }

    }

    private func extractIntefaceArray(from networklist:String) -> [String] {
        //Loop over lines of shell response to find all lines that are an interface
        var interfaceArray = [String]()
        networklist.enumerateLines { (line, stop) -> () in
            //find lines that start with (number)
            let regexmatch = self.matches(for: "^\\(([1-9][0-9]*)\\).*", in: line)
            if (regexmatch.count == 1) {
                //trim the (number) off the start of the line
                interfaceArray.append(self.trimString(of: line))
            }
        }
        return interfaceArray
    }

    private func switchInterface(fromList networkList:String, to search:String) {
        var interfaceArray = extractIntefaceArray(from: networkList)
        //Make sure that the specified network interface is in the network list
        guard let i = interfaceArray.index(of: search) else {
            print("Error: The specified network interface " + search + " was not found in the interface list.")
            return
        }

        //reorder the interface list
        interfaceArray.remove(at: i)
        interfaceArray.insert(search, at: 0)

        //Add ordernetworkservices argument at the beggining
        interfaceArray.insert("ordernetworkservices", at: 0)

        //Update the network interface priority
        let _ = shell(launchPath: CommandLineTool.networksetup, arguments: interfaceArray)
        print("Succesfully updated the network interface priority.")
    }

    //Interface array is an array of interfaces from listnetworkserviceorder response
    //Toggle array is an array of interfaces to switch between
    private func determineToggle(interfaces interfaceArray: [String], toggles toggleArray: [String]) -> String? {
        //This array correlates with toggleArray and stores current
        //priority of interfaces
        var currentPriority = [Int]()

        //loop over all interfaces in toggle array
        for interface in toggleArray {
            //Try to get the interface's location in the current
            //network service order. return an error if it is not
            //in the list.
            guard let interfaceIndex = interfaceArray.index(of: interface) else {
                print("Interface " + interface + " was not found in the interface list.")
                return nil
            }

            //Add the index to the currentPriority array
            currentPriority.append(interfaceIndex)
        }

        // Determine which interface should be switched to next
        let highestPriorityIndex = currentPriority.index(of: currentPriority.min()!)
        var indexToSwitchTo: Int

        //If this is the end of the array, select the first element
        if (highestPriorityIndex == toggleArray.count - 1) {
            indexToSwitchTo = 0
        }
        //Otherwise, select the next element
        else {
            indexToSwitchTo = highestPriorityIndex! + 1
        }

        return toggleArray[indexToSwitchTo]
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