import Foundation
public final class CommandLineTool {
    private let arguments: [String]
    static let networksetup:String = "/usr/sbin/networksetup" 

    public init(arguments: [String] = CommandLine.arguments) { 
        self.arguments = arguments
    }

    public func run() throws {
        guard arguments.count == 3 else {
            print("Error: incorrect number of parameters specified")
            return
        }

        let type = arguments[1]

        switch type {
            case "-s":
                Switch(ToInterface: arguments[2])
            case "-t":
                Toggle(FromFile: arguments[2])
            default:
                print("hi")
        }
    }

    public func Switch(ToInterface interface: String) {
        //Execute shell command to get list of network service order
        let networkList = shell(launchPath: CommandLineTool.networksetup, arguments: ["listnetworkserviceorder"])

        switchInterface(fromList: networkList, to: interface)
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
            print("Could not find file")
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
            print("Error: The specified network interface was not found in the interface list.")
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