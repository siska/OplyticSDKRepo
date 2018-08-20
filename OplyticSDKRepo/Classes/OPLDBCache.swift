//
//  OPLDBCache.swift
//  Oplytic
//
//  Copyright © 2017 Oplytic. All rights reserved.
//

import UIKit

let SQLITE_STATIC = unsafeBitCast(0, to: sqlite3_destructor_type.self)
let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
let EVENT_TABLE_NAME = "appevents"
let APPEVENTURL = URL(string: "https://api.oplct.com/appevent")
let DISABLEHOURS_KEY = "disablehours"
let LASTDISABLED_KEY = "lastdisabled"
let REQUESTTIMEOUT = 10.0

public class OPLDBCache: NSObject
{
    private var _db: OpaquePointer? = nil
    private var _dbFolder : URL? = nil
    private var _dbPath : String = ""
    private var _lastDisabled : NSDate? = nil
    private var _disableHours : Double? = nil
    public var NewlyInstalled : Bool = false
    public static let sharedInstance = OPLDBCache()

    override init()
    {
        super.init()
        openSqlLiteDB()
        _disableHours = UserDefaults.standard.object(forKey: DISABLEHOURS_KEY) as? Double
        _lastDisabled = UserDefaults.standard.object(forKey: LASTDISABLED_KEY) as? NSDate

        //_disableHours = nil
        //_lastDisabled = nil
        //disableEvents(hours: 1 / 60)
    }

    public func addEvent(data: [String: String])
    {
        if(eventsDisabled())
        {
            return
        }
        //TODO::handle exceptions better
        cacheEvent(data: data)
        sendEvent(payload: data)
    }

    public func sendEvents()
    {
        if(eventsDisabled())
        {
            return
        }
        let event = getNextEvent()
        if(event != nil)
        {
            sendEvent(payload: event!)
        }
    }

    private func disableEvents(hours: Double)
    {
        if(hours > 0)
        {
            _disableHours = hours
            _lastDisabled = NSDate()
            UserDefaults.standard.set(_disableHours, forKey: DISABLEHOURS_KEY)
            UserDefaults.standard.set(_lastDisabled, forKey: LASTDISABLED_KEY)
        }
    }

    private func eventsDisabled() -> Bool
    {
        if(_disableHours != nil && _disableHours! > 0 && _lastDisabled != nil)
        {
            let secondsDisabled = NSDate().timeIntervalSinceReferenceDate - (_lastDisabled?.timeIntervalSinceReferenceDate)!
            let hoursDisabled = secondsDisabled / 3600;
            if(_disableHours! > hoursDisabled)
            {
                return true;
            }
            else
            {
                _disableHours = nil;
                _lastDisabled = nil
                UserDefaults.standard.set(_disableHours, forKey: DISABLEHOURS_KEY)
                UserDefaults.standard.set(_lastDisabled, forKey: LASTDISABLED_KEY)
            }
        }
        return false
    }

    private func openSqlLiteDB()
    {
        initializeSqlLitePaths()

        if (FileManager.default.fileExists(atPath: _dbPath))
        {
            if sqlite3_open(_dbPath, &_db) != SQLITE_OK
            {
                let errorMessage = String(cString: sqlite3_errmsg(_db))
                NSLog("Unable to create database. Error: \(errorMessage)")
            }
        }
        else
        {
            //deleteDB() //for testing
            createDB()
        }
    }


    private func initializeSqlLitePaths()
    {
        let cacheDirUrl = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        _dbFolder = cacheDirUrl.appendingPathComponent("oplytic")
        _dbPath = (_dbFolder?.appendingPathComponent("opldb.sqlite").path)!
        var isDir : ObjCBool = false
        if (!FileManager.default.fileExists(atPath: _dbPath, isDirectory: &isDir)) {
            do
            {
                try FileManager.default.createDirectory(atPath: (_dbFolder?.path)!,
                                                        withIntermediateDirectories: true,
                                                        attributes: nil)
            }
            catch let error as NSError
            {
                let errorMessage = error.localizedDescription
                NSLog("Could not create cache directory: \(errorMessage)")
            }
        }
    }

    private func createDB()
    {
        NewlyInstalled = true
        var result : Int32 = 0

        result = sqlite3_open(_dbPath, &self._db)
        if (result == SQLITE_OK) {
            result = sqlite3_exec(self._db, "BEGIN", nil, nil, nil)
            if result == SQLITE_OK {
                result = createEventTable()
            }
            if (result == SQLITE_OK || result == SQLITE_DONE) {
                sqlite3_exec(self._db, "COMMIT", nil, nil, nil)
            } else {
                sqlite3_exec(self._db, "ROLLBACK", nil, nil, nil)
            }
        } else {
            let errorMessage = String(cString: sqlite3_errmsg(_db))
            NSLog("Unable to create database. Error: \(errorMessage)")
        }
    }

    private func createEventTable() -> Int32
    {
        var result : Int32 = 0

        var createTableStatement: OpaquePointer? = nil
        let sql = "CREATE TABLE IF NOT EXISTS \(EVENT_TABLE_NAME) (" +
            "\(CLIENTEVENTTOKEN_KEY) CHAR(40) PRIMARY KEY," +
            "\(DEVICETOKEN_KEY) CHAR(40)," +
            "\(CLICKTOKEN_KEY) CHAR(40), " +
            "\(APPID_KEY) CHAR(100), " +
            "\(EVENTID_KEY) CHAR(40), " +
            "\(EVENTACTION_KEY) CHAR(20)," +
            "\(EVENTOBJECT_KEY) CHAR(20)," +
            "\(STR1_KEY) CHAR(40)," +
            "\(STR2_KEY) CHAR(40)," +
            "\(STR3_KEY) CHAR(40)," +
            "\(NUM1_KEY) CHAR(40)," + // numeric value, normalized to text
            "\(NUM2_KEY) CHAR(40)," +
            "\(TIMESTAMP_KEY) INTEGER default CURRENT_TIMESTAMP" +
        ")"

        result = sqlite3_prepare_v2(self._db, sql, -1, &createTableStatement, nil)
        if result == SQLITE_OK {
            result = sqlite3_step(createTableStatement)
            if result != SQLITE_DONE {
                let errorMessage = String(cString: sqlite3_errmsg(self._db))
                NSLog("Events table could not be created. Error: \(errorMessage)")
            } else {
                result = SQLITE_OK
            }
        }
        if result == SQLITE_OK {
            sqlite3_finalize(createTableStatement)
        }
        return result
    }

    public func cacheEvent(data: [String: String])
    {
        //TODO::on failure return false, log the failure
        var insertStatement: OpaquePointer? = nil
        let sql = "INSERT INTO \(EVENT_TABLE_NAME) (" +
            "\(CLIENTEVENTTOKEN_KEY)," +
            "\(DEVICETOKEN_KEY)," +
            "\(CLICKTOKEN_KEY)," +
            "\(APPID_KEY)," +
            "\(EVENTID_KEY)," +
            "\(EVENTACTION_KEY)," +
            "\(EVENTOBJECT_KEY)," +
            "\(STR1_KEY)," +
            "\(STR2_KEY)," +
            "\(STR3_KEY)," +
            "\(NUM1_KEY)," +
            "\(NUM2_KEY)" +
        ") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);"

        let clientEventToken = data[CLIENTEVENTTOKEN_KEY]
        let deviceToken = data[DEVICETOKEN_KEY]
        let clickToken = data[CLICKTOKEN_KEY]
        let appId = data[APPID_KEY]
        let eventId = data[EVENTID_KEY]
        let eventAction = data[EVENTACTION_KEY]
        let eventObject = data[EVENTOBJECT_KEY]
        let str1 = data[STR1_KEY]
        let str2 = data[STR2_KEY]
        let str3 = data[STR3_KEY]
        let num1 = data[NUM1_KEY]
        let num2 = data[NUM2_KEY]

        if (sqlite3_prepare_v2(self._db, sql, -1, &insertStatement, nil) != SQLITE_OK) {
            let errorMessage = String(cString: sqlite3_errmsg(self._db))
            NSLog("Error adding event: \(errorMessage)")
            return
        }
        sqlite3_bind_text(insertStatement, 1, clientEventToken, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(insertStatement, 2, deviceToken, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(insertStatement, 3, clickToken, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(insertStatement, 4, appId, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(insertStatement, 5, eventId, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(insertStatement, 6, eventAction, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(insertStatement, 7, eventObject, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(insertStatement, 8, str1, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(insertStatement, 9, str2, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(insertStatement, 10, str3, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(insertStatement, 11, num1, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(insertStatement, 12, num2, -1, SQLITE_TRANSIENT)

        sqlite3_step(insertStatement!)

        sqlite3_finalize(insertStatement)
    }

    public func getEventCount() -> Int32
    {
        var status : Int32 = SQLITE_OK
        var count : Int32 = 0
        let sql = "SELECT count(*) FROM \(EVENT_TABLE_NAME)"
        var selectEventCount : OpaquePointer? = nil

        status = sqlite3_prepare_v2(self._db, sql, -1, &selectEventCount, nil)
        if status == SQLITE_OK {
            status = sqlite3_step(selectEventCount)
            if status == SQLITE_ROW {
                count = sqlite3_column_int(selectEventCount, 0)
            } else {
                let errorMessage = String(cString: sqlite3_errmsg(self._db))
                NSLog("Event count can not be read. Error: \(errorMessage)")
            }
        }
        sqlite3_finalize(selectEventCount)
        return count
    }

    private func getNextEvent() -> ([String : Any]?)
    {
        let sql = "SELECT " +
            "\(CLIENTEVENTTOKEN_KEY)," +
            "\(DEVICETOKEN_KEY)," +
            "\(CLICKTOKEN_KEY), " +
            "\(APPID_KEY)," +
            "\(EVENTID_KEY), " +
            "\(EVENTACTION_KEY)," +
            "\(EVENTOBJECT_KEY)," +
            "\(STR1_KEY)," +
            "\(STR2_KEY)," +
            "\(STR3_KEY)," +
            "\(NUM1_KEY)," +
            "\(NUM2_KEY)," +
            "strftime('%Y-%m-%dT%H:%M:%fZ', \(TIMESTAMP_KEY)) " +
        "FROM \(EVENT_TABLE_NAME) order by rowid limit 1"

        var statement: OpaquePointer? = nil
        sqlite3_prepare_v2(self._db, sql, -1, &statement, nil)

        if (sqlite3_step(statement) != SQLITE_ROW)
        {
            return nil;
        }

        var payload : [String : Any] = [:]
        let clienteventtoken = sqlite3_column_text(statement, 0)
        if clienteventtoken != nil {
            payload[CLIENTEVENTTOKEN_KEY] = String(cString: clienteventtoken!)
        }

        let deviceToken = sqlite3_column_text(statement, 1)
        if deviceToken != nil {
            payload[DEVICETOKEN_KEY] = String(cString: deviceToken!)
        }

        let clickToken = sqlite3_column_text(statement, 2)
        if clickToken != nil {
            payload[CLICKTOKEN_KEY] = String(cString: clickToken!)
        }

        let appId = sqlite3_column_text(statement, 3)
        if appId != nil {
            payload[APPID_KEY] = String(cString: appId!)
        }

        let eventid = sqlite3_column_text(statement, 4)
        if eventid != nil {
            payload[EVENTID_KEY] = String(cString: eventid!)
        }

        let eventaction = sqlite3_column_text(statement, 5)
        if eventaction != nil {
            payload[EVENTACTION_KEY] = String(cString: eventaction!)
        }

        let eventobject = sqlite3_column_text(statement, 6)
        if eventobject != nil {
            payload[EVENTOBJECT_KEY] = String(cString: eventobject!)
        }

        let str1 = sqlite3_column_text(statement, 7)
        if str1 != nil {
            payload[STR1_KEY] = String(cString: str1!)
        }

        let str2 = sqlite3_column_text(statement, 8)
        if str2 != nil {
            payload[STR2_KEY] = String(cString: str2!)
        }

        let str3 = sqlite3_column_text(statement, 9)
        if str3 != nil {
            payload[STR3_KEY] = String(cString: str3!)
        }

        let num1 = sqlite3_column_text(statement, 10)
        if num1 != nil {
            payload[NUM1_KEY] = Double(String(cString: num1!))
        }

        let num2 = sqlite3_column_text(statement, 11)
        if num2 != nil {
            payload[NUM2_KEY] = Double(String(cString: num2!))
        }

        let timestamp = sqlite3_column_text(statement, 12)
        if timestamp != nil {
            payload[TIMESTAMP_KEY] = String(cString: timestamp!)
        }

        sqlite3_finalize(statement)
        return payload;
    }

    func deleteEvent(payload: [String:Any]) -> Bool
    {
        var result : Bool = false
        var status : Int32 = 0
        let sql = "DELETE from \(EVENT_TABLE_NAME) WHERE \(CLIENTEVENTTOKEN_KEY) = ?"

        var deleteStatement: OpaquePointer? = nil

        let clienteventtoken = payload[CLIENTEVENTTOKEN_KEY] as? String
        if clienteventtoken != nil {
            sqlite3_prepare_v2(self._db, sql, -1, &deleteStatement, nil)
            sqlite3_bind_text(deleteStatement, 1, clienteventtoken, -1, SQLITE_TRANSIENT)
            status = sqlite3_step(deleteStatement)
            if status == SQLITE_OK || status == SQLITE_DONE {
                result = true
            }
        }
        return result
    }

    private func deleteDB()
    {
        do
        {
            try FileManager.default.removeItem(atPath:(_dbFolder?.path)!)
            try FileManager.default.createDirectory(atPath: (_dbFolder?.path)!,
                                                    withIntermediateDirectories: true,
                                                    attributes: nil)
        }
        catch let error as NSError
        {
            NSLog("Could not delete cache database: \(error.localizedDescription)")
        }
    }

    private func clearEventCache()
    {
        let deletesql = "DELETE FROM \(EVENT_TABLE_NAME)"
        sqlite3_exec(self._db, deletesql, nil, nil, nil)
    }

    private func convertToDictionary(text: String) -> [String: Any]?
    {
        if let data = text.data(using: .utf8)
        {
            do
            {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            }
            catch
            {
                print(error.localizedDescription)
            }
        }
        return nil
    }


    private func sendEvent(payload: [String:Any])
    {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted)
            let jsonStr = String(data: jsonData, encoding: .utf8)
            print("Sending event request to \(APPEVENTURL!)")
            print("JSON Payload: \(jsonStr!)")

            var request = URLRequest(url: APPEVENTURL!,
                                     cachePolicy: .reloadIgnoringCacheData,
                                     timeoutInterval: REQUESTTIMEOUT)
            request.httpMethod = "POST"
            request.httpBody = jsonData
            request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let httpStatus = response as? HTTPURLResponse
                {
                    let status = httpStatus.statusCode
                    let serialQueue = DispatchQueue(label: "oplytic")
                    serialQueue.sync
                        {
                            self.handleResponse(payload: payload, status: status, data: data, error: error)
                    }
                }
            }
            task.resume()
        }
        catch
        {

        }
    }

    private func handleResponse(payload: [String: Any]?, status: Int, data: Data?, error: Error?)
    {
        if(status != 200)
        {
            //some sort of network error like wireless offline or server offline or database issue,
            //leave the event in cache to be resent later
            var msg = "Oplytic | Network Error \(status) : "
            if(error != nil)
            {
                msg += " \(String(describing: error?.localizedDescription))"
            }
            NSLog(msg)
            return
        }

        if(data != nil)
        {
            do {
                let json = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as! [String:Any]
                if let statusText = json["status"] as! String?
                {
                    if let message = json["message"] as! String?
                    {
                        if(statusText.lowercased() == "freeze")
                        {
                            if let hours = Double(message)
                            {
                                disableEvents(hours: hours)
                                NSLog("Oplytic | Freezing app events for \(hours) hours")
                            }
                        }
                        else if(statusText.lowercased() == "error")
                        {
                            NSLog("Oplytic | Error removing event from cache")
                        }
                    }
                }
            } catch let error as NSError {
                NSLog("Oplytic | Error serializing response \(error)")
            }

            if (deleteEvent(payload: payload!))
            {
                //"recursively" call sendEvents to send any remaining events in the cache
                sendEvents()
            }
            else
            {
                //TODO::handle this exception, log better
                NSLog("Oplytic | Error removing event from cache")
            }

        }
    }
}

