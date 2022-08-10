//
//  Common.swift
//  CoinPrice
//
//  Created by rbcoder on 2021/10/1.
//

import Cocoa
import Automator

class Common: NSObject {
    //组合stream
    public static let baseURL = "wss://fstream.binance.com/stream?streams="
    //单一stream
    public static let baseURL2 = "wss://fstream.binance.com/ws/"
    
    /*
    public static func filePath(fileName: String) -> URL {
        let mainPaths = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)
        let pathURL = URL(string: mainPaths.first!)
        let filepath = pathURL?.appendingPathComponent(fileName)
        return filepath!
    }
    
    //保存自选列表到本地
    private func saveArrayToFile(array: NSArray) {
        let filePath = Common.filePath(fileName: "favourites.plist")
        array.write(toFile: filePath.absoluteString, atomically: true)
    }
    
    //读取本地自选列表
    private func readArrayFromFile() -> NSArray {
        let filePath = Common.filePath(fileName: "favourites.plist")
        if let array = NSArray(contentsOfFile: filePath.absoluteString) {
            return array
        } else {
            return []
        }
    }
    */
    
    public static func saveUserPreference(object: Preference) {
        let jsonEncoder = JSONEncoder()
        let data = try? jsonEncoder.encode(object)
        UserDefaults.standard.set(data, forKey: "UserPreference")
        UserDefaults.standard.synchronize()
    }
    
    public static func readUserPreference() -> Preference? {
        let jsonData = UserDefaults.standard.data(forKey: "UserPreference")
        let jsonDecoder = JSONDecoder()
        if let data = jsonData {
            guard let object = try? jsonDecoder.decode(Preference.self, from: data) else { return nil }
            return object
        }
        
        return nil
        
    }
    
    public static func getMinute() -> (Int, Int) {
        let dateformatter = DateFormatter()
        let timeZone = TimeZone.init(identifier: "Asia/Beijing")
        dateformatter.timeZone = timeZone
        dateformatter.dateFormat = "mm"
        let m = dateformatter.string(from: Date.init())
        dateformatter.dateFormat = "ss"
        let s = dateformatter.string(from: Date.init())
        let mm = Int(m) ?? 0
        let ss = Int(s) ?? 0
        return (mm, ss)
    }
    
    
    public static func autoSendEmail(_ subject:String, _ body: String) {
        
        //此处对应的是在Automator中定义的变量
        let POSSIBLE_VARIABLES = ["sub":subject, "body":body]
        
        var url = try! FileManager.default.url(
            for: FileManager.SearchPathDirectory.applicationScriptsDirectory,
               in: FileManager.SearchPathDomainMask.userDomainMask,
               appropriateFor:nil,
               create: false)
        url.appendPathComponent("SendPriceEmail.workflow")//PostCoinsPriceByEmail.workflow
        print("脚本地址是：\(url)")
        if let automatorTask = try? NSUserAutomatorTask(url: url) {
            if let varChecker = try? AMWorkflow(contentsOf: url) {
                automatorTask.variables = POSSIBLE_VARIABLES.filter {
                    return varChecker.setValue($0.value, forVariableWithName: $0.key)
                    // -or- //
                    //                    return varChecker.valueForVariable(withName: $0.key) != nil
                }
            }
            automatorTask.execute(withInput: nil, completionHandler: nil)
        }
    }
        
        
        
        /*
         总结：1， 如果是开启了沙盒sandbox的应用，无法将 .workflow 放在APP的bundle中执行
              2， 如果关闭sandbox（将不能联网，基本废了），工作流文件可放在APP的bundle中，使用 AMWorkflow 执行
              3， 如果一定要开启sandbox，可将工作流放在 ~/Library/Application%20Scripts/ 中，使用 NSUserAutomatorTask 执行
              4， 详情参考 NSUserAutomatorTask 官方介绍
         */
//        guard let workflowPath = Bundle.main.path(forResource: "PostCoinsPriceByEmail", ofType: "workflow") else {
//                print("Workflow resource not found")
//                return
//            }
//
//            let workflowURL = URL(fileURLWithPath: workflowPath)
//            do {
//                try AMWorkflow.run(at:workflowURL, withInput: nil)
//            } catch {
//                print("Error running workflow: \(error)")
//            }
        

/*
    有可能实现自动静默发动邮件的方法，有空再研究。  要安装配置postfix服务
 */
/*
    fileprivate let mailQueue = DispatchQueue.global(qos: .background)
    /// Sends an email using the postfix unix utility.
    ///
    /// - Note: Ths function only works if postfix is running (and set up correctly)
    ///
    /// - Parameters:
    ///   - mail: The email to be transmitted. It should -as a minimum- contain the To, From and Subject fields.
    ///   - domainName: The domain this email is sent from, used for logging purposes only.

    public func sendEmail(_ mail: String, domainName: String) {
        // Do this on a seperate queue in the background so this operation is non-blocking.
        mailQueue.async { [mail, domainName] in
            // Ensure the mail is ok
            guard let utf8mail = mail.data(using: .utf8), utf8mail.count > 0 else {
                return
            }
            let options: Array<String> = ["-t"] // This option tells sendmail to read the from/to/subject from the email string itself.

            let errpipe = Pipe() // should remain empty
            let outpipe = Pipe() // should remain empty (but if you use other options you may get some text)
            let inpipe = Pipe()  // will be used to transfer the mail to sendmail

            // Setup the process that will send the mail

            let process = Process()
            if #available(OSX 10.13, *) {
                process.executableURL = URL(fileURLWithPath: "/usr/sbin/sendmail")
            } else {
                process.launchPath = "/usr/sbin/sendmail"
            }
            process.arguments = options
            process.standardError = errpipe
            process.standardOutput = outpipe
            process.standardInput = inpipe

            // Start the sendmail process

            let data: Data
            do {
                // Setup the data to be sent
                inpipe.fileHandleForWriting.write(utf8mail)

                // Start the sendmail process
                if #available(OSX 10.13, *) {
                    try process.run()
                } else {
                    process.launch()
                }

                // Data transfer complete
                inpipe.fileHandleForWriting.closeFile()


                // Set a timeout. 10 seconds should be more than enough.
                let timeoutAfter = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + UInt64(10000) * 1000000)


                // Setup the process timeout on another queue
                DispatchQueue.global().asyncAfter(deadline: timeoutAfter) {
                    [weak process] in
                    process?.terminate()
                }

                // Wait for sendmail to complete
                process.waitUntilExit()

                // Check termination reason & status
                if (process.terminationReason == .exit) && (process.terminationStatus == 0) {

                    // Exited OK, return data
                    data = outpipe.fileHandleForReading.readDataToEndOfFile()

                    if data.count > 0 {
                        print("Unexpectedly read \(data.count) bytes from sendmail, content: \(String(data: data, encoding: .utf8) ?? "")")
                    } else {
                        print("Sendmail completed without error")
                    }

                } else {

                    // An error of some kind happened
                    print("Sendmail process terminations status = \(process.terminationStatus), reason = \(process.terminationReason.rawValue )")
                    
                    let dateFormatter = DateFormatter()
                    let timeZone = TimeZone.init(identifier: "Asia/Beijing")
                    dateFormatter.timeZone = timeZone
                    dateFormatter.dateFormat = "YYYY-MM-DD-HH-mm-ss"
                    let now = dateFormatter.string(from: Date())

                    print("Sendmail process failure, check domain (\(domainName)) logging directory for an error entry with timestamp \(now)")


                    // Error, grab all possible output and create a file with all error info
                    let e = errpipe.fileHandleForReading.readDataToEndOfFile()
                    let d = outpipe.fileHandleForReading.readDataToEndOfFile()

                    let dump =
                    """
                    Process Termination Reason: \(process.terminationReason.rawValue)
                    Sendmail exit status: \(process.terminationStatus)
                    Details:
                    - Sendmail Executable  : /usr/sbin/sendmail
                    - Sendmail Options     : -t
                    - Sendmail Timeout     : 10,000 mSec
                    - Sendmail Error output: \(e.count) bytes
                    - Sendmail Output      : \(d.count) bytes
                    Below the output of sendmail is given in the following block format:
                    (----- Email input -----)
                    ...
                    (----- Standard Error -----)
                    ...
                    (----- Standard Out -----)
                    ...
                    (----- End of output -----)

                    (----- Email input -----)
                    \(mail)
                    (----- Standard Error -----)
                    \(String(bytes: e, encoding: .utf8) ?? "")
                    (----- Standard Out -----)
                    \(String(bytes: d, encoding: .utf8) ?? "")
                    (----- End of output -----)
                    """

                    let errorFileName = "sendmail-error-log-" + now
//                    if let errorFileUrl = Urls.domainLoggingDir(for: domainName)?.appendingPathComponent(errorFileName).appendingPathExtension("txt"),
//                        let dumpData = dump.data(using: .utf8),
//                        ((try? dumpData.write(to: errorFileUrl)) != nil) {
//                    } else {
//                        print("Cannot create sendmail error file, content is: \n\(dump)\n")
//                    }
                }

            } catch let error {

                print("Exception occured during sendmail execution, message = \(error.localizedDescription)")
            }
        }
    }
 */
 
 
}
